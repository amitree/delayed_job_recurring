#
# Delayed::RecurringJob
#
# Inspired by https://gist.github.com/ginjo/3688965
#
module Delayed
  module RecurringJob
    def self.included(base)
      require 'fugit' unless defined?(Fugit)
      base.extend(ClassMethods)
      base.class_eval do
        @@logger = Delayed::Worker.logger
        cattr_reader :logger
      end
    end

    def failure
      schedule!
    end

    def success
      schedule!
    end

    # Schedule this "repeating" job
    def schedule! options = {}
      options = options.dup

      if run_every = options.delete(:run_every)
        options[:run_interval] = serialize_duration(run_every)
      end

      @schedule_options = options.reverse_merge(@schedule_options || {}).reverse_merge(
        cron: self.class.cron,
        run_at: self.class.run_at,
        timezone: self.class.timezone,
        run_interval: serialize_duration(self.class.run_every),
        priority: self.class.priority,
        queue: self.class.queue
      )

      enqueue_opts = { priority: @schedule_options[:priority], run_at: next_run_time }
      enqueue_opts[:queue] = @schedule_options[:queue] if @schedule_options[:queue]

      Delayed::Job.transaction do
        self.class.jobs(@schedule_options).destroy_all
        if Gem.loaded_specs['delayed_job'].version.to_s.first.to_i < 3
          Delayed::Job.enqueue self, enqueue_opts[:priority], enqueue_opts[:run_at]
        else
          Delayed::Job.enqueue self, enqueue_opts
        end
      end
    end

    def next_run_time
      return @schedule_options[:cron].next_time if @schedule_options[:cron].respond_to?(:next_time)

      times = @schedule_options[:run_at]
      times = [times] unless times.is_a? Array
      times = times.map{|time| parse_time(time, @schedule_options[:timezone])}
      times = times.map{|time| time.in_time_zone @schedule_options[:timezone]} if @schedule_options[:timezone]

      interval = deserialize_duration(@schedule_options[:run_interval])

      until next_time = next_future_time(times)
        times.map!{ |time| time + interval }
      end

      # Update @schedule_options to avoid growing number of calculations each time
      @schedule_options[:run_at] = times

      next_time
    end

  private
    # We don't want the run_interval to be serialized as a number of seconds.
    # 1.day is not the same as 86400 (not all days are 86400 seconds long!)
    def serialize_duration(duration)
      case duration
      when ActiveSupport::Duration
        {value: duration.value, parts: duration.parts}
      else
        duration
      end
    end

    def deserialize_duration(serialized)
      case serialized
      when Hash
        ActiveSupport::Duration.new(serialized[:value], serialized[:parts])
      else
        serialized
      end
    end

    def parse_time(time, timezone)
      case time
      when String
        time_with_zone = get_timezone(timezone).parse(time)
        parts = Date._parse(time, false)
        wday = parts.fetch(:wday, time_with_zone.wday)
        time_with_zone + (wday - time_with_zone.wday).days
      else
        time
      end
    end

    def get_timezone(zone)
      if zone
        ActiveSupport::TimeZone.new(zone)
      else
        Time.zone
      end
    end

    def next_future_time(times)
      times.select{|time| time > Time.now}.min
    end

    module ClassMethods

      def cron(cronline = false)
        return @cron if defined? @cron && cronline == false
        return (@cron = nil) if cronline.nil?

        if cronline
          @cron = Fugit.parse(cronline)
          raise ArgumentError, 'Only cron and "natural language" syntax supported' unless @cron.is_a?(Fugit::Cron)
        end

        @cron
      end

      def run_at(*times)
        if times.length == 0
          @run_at || run_every.from_now
        else
          if @run_at_inherited
            @run_at = []
            @run_at_inherited = nil
          end
          @run_at ||= []
          @run_at.concat times
        end
      end

      def run_every(interval = nil)
        if interval.nil?
          @run_interval || 1.hour
        else
          @run_interval = interval
        end
      end

      def timezone(zone = nil)
        if zone.nil?
          @tz
        else
          @tz = zone
        end
      end

      def priority(priority = nil)
        if priority.nil?
          @priority
        else
          @priority = priority
        end
      end

      def queue(*args)
        if args.length == 0
          @queue
        else
          @queue = args.first
        end
      end

      # Show all jobs for this schedule
      def jobs(options = {})
        options = options.with_indifferent_access

        # Construct dynamic query with 'job_matching_param' if present
        query = ["((handler LIKE ?) OR (handler LIKE ?))", "--- !ruby/object:#{name} %", "--- !ruby/object:#{name}\n%"]
        if options[:job_matching_param].present?
          matching_key = options[:job_matching_param]
          matching_value = options[matching_key]
          matching_yaml = yaml_quote(matching_value)
          query[0] = "#{query[0]} AND handler LIKE ?"
          query << "%#{matching_key}: #{matching_yaml}%"
        end

        ::Delayed::Job.where(query)
      end

      # Remove all jobs for this schedule (Stop the schedule)
      def unschedule(options = {})
        jobs(options).each{|j| j.destroy}
      end

      # Main interface to start this schedule (adds it to the jobs table).
      # Pass in a time to run the first job (nil runs the first job at run_interval from now).
      def schedule(options = {})
        schedule!(options) unless scheduled?(options)
      end

      def schedule!(options = {})
        return unless Delayed::Worker.delay_jobs
        unschedule(options)
        new.schedule!(options)
      end

      def scheduled?(options = {})
        jobs(options).count > 0
      end

      def inherited(subclass)
        [:@run_at, :@run_interval, :@tz, :@priority, :@cron].each do |var|
          next unless instance_variable_defined? var
          subclass.instance_variable_set var, self.instance_variable_get(var)
          subclass.instance_variable_set "#{var}_inherited", true
        end
      end

    private
      def yaml_quote(value)
        # In order to ensure matching indentation, place the element inside a
        # two-level hash (the first level mimicking 'schedule_options', the second
        # for #{job_matching_param}), and strip out the leading "---\n:a:\n  :a: "
        # but keep the trailing newline.
        ({a: {a: value}}).to_yaml[14..-1]
      end
    end # ClassMethods
  end # RecurringJob
end # Delayed
