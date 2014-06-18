#
# Delayed::RecurringJob
#
# Inspired by https://gist.github.com/ginjo/3688965
#
module Delayed
  module RecurringJob
    def self.included(base)
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
      @schedule_options = options.reverse_merge(@schedule_options || {}).reverse_merge(
        run_at: self.class.run_at,
        timezone: self.class.timezone,
        run_interval: serialize_duration(self.class.run_every)
      )

      enqueue_opts = { priority: 0, run_at: next_run_time }

      if Gem.loaded_specs['delayed_job'].version.to_s.first.to_i < 3
        Delayed::Job.enqueue self, enqueue_opts[:priority], enqueue_opts[:run_at]
      else
        Delayed::Job.enqueue self, enqueue_opts
      end
    end

    def next_run_time
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
        get_timezone(timezone).parse(time)
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
      def run_at(*times)
        if times.length == 0
          @run_at || run_every.from_now
        else
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

      # Show all jobs for this schedule
      def jobs
        ::Delayed::Job.where("(handler LIKE ?) OR (handler LIKE ?)", "--- !ruby/object:#{name} %", "--- !ruby/object:#{name}\n%")
      end

      # Remove all jobs for this schedule (Stop the schedule)
      def unschedule
        jobs.each{|j| j.destroy}
      end

      # Main interface to start this schedule (adds it to the jobs table).
      # Pass in a time to run the first job (nil runs the first job at run_interval from now).
      def schedule(options = {})
        schedule!(options) if Delayed::Worker.delay_jobs && !scheduled?
      end

      def schedule!(options = {})
        new.schedule!(options)
      end

      def scheduled?
        jobs.count > 0
      end

    end # ClassMethods
  end # RecurringJob

  module Task
    # Creates a new class wrapper around a block of code to be scheduled.
    def self.new(name, options, &block)
      task_class = Class.new
      task_class.class_eval do
        include Delayed::RecurringJob

        def display_name
          self.class.name
        end

        def perform
          block.call
        end
      end

      Object.const_set(name, task_class) if name
      task_class.schedule(options)
      return task_class
    end

    # Schedule a block of code on-the-fly.
    # This is a friendly wrapper for using Task.new without an explicit constant assignment.
    # Delayed::Task.schedule('MyNewTask', run_every: 10.minutes, run_at: 1.minute.from_now){do_some_stuff_here}
    # or
    # Delayed::Task.schedule(run_every: 10.minutes, run_at: 1.minute.from_now){do_some_stuff_here}
    def self.schedule(name_or_options={}, options={}, &block)
      case name_or_options
      when Hash
        name, options = nil, name_or_options
      else
        name = name_or_options
      end

      self.new name, options, &block
    end
  end  # Task
end # Delayed
