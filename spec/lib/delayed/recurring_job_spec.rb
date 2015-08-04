require 'spec_helper'
require 'delayed_job_recurring'

class MyTask
  include ::Delayed::RecurringJob

  run_every 1.day

  cattr_accessor :run_count
  @@run_count = 0

  def display_name
    "MyCoolTask"
  end

  def perform
    @@run_count += 1
  end
end

class MyTas
  include ::Delayed::RecurringJob

  run_every 1.day

  def perform
  end
end

class MyTaskThatFails < MyTask
  run_every 1.day
  def perform
    raise 'fail'
  end
end

class MyTaskWithZone < MyTask
  run_at '5:00am'
  run_every 1.day
  timezone 'US/Pacific'
  priority 0
end

class SubTaskWithZone < MyTaskWithZone
  run_at '6:00am'
end

class MyTaskWithIVars < MyTask
  def initialize
    @foo = 'bar'
  end
end

module MyModule
  class MySubTask < MyTask
  end
end

class MyTask1 < MyTask; end
class MyTask2 < MyTask; end
class MyTask3 < MyTask; end

class MyTaskWithPriority < MyTask
  priority 2
end

class MyTaskWithQueueName < MyTask
  queue 'other-queue'
end

class MySelfSchedulingTask < MyTask
  def perform
    # Purpose of scheduling ourselves within the perform isn't a use case
    # but simply a method of testing the case where our job is scheduled
    # while we are processing an 'existing' job (of the same type).
    #
    # An example of such as case is (for ease of development/testing) having
    # a recurring job scheduled in an initializer. Using a process manager,
    # it is possible to have a situation where DJ spools up a previously
    # scheduled job, then (possibly due to a longer load time) another process
    # runs its initializer also scheduling up a new job. Then when the running
    # job finishes, it schedules itself resulting in two of the same job in DJ
    self.class.schedule!(run_at: Time.now + 1.second, timezone: 'US/Pacific')
  end
end

describe Delayed::RecurringJob do
  describe '#schedule' do
    context "when delayed job are disabled" do
      before do
        Delayed::Worker.delay_jobs = false
      end

      after do
        Delayed::Worker.delay_jobs = true
      end

      it "does not execute job" do
        expect { MyTask.schedule }.not_to change(MyTask, :run_count)
      end

      it "does not schedule job" do
        MyTask.schedule
        expect(MyTask.scheduled?).to eq false
      end
    end

    context "with a single run_at time" do
      context "initially" do
        it "runs at the specified time if it's in the future" do
          at '2014-03-08T12:00:00' do
            job = MyTask.schedule(run_at: dt('2014-03-08T13:00:00'))
            expect(job.run_at.to_datetime).to eq dt('2014-03-08T13:00:00')
          end
        end

        it "runs on the next occurrence of the specified time if it's in the past" do
          at '2014-03-08T12:00:00' do
            job = MyTask.schedule(run_at: dt('2014-03-08T11:00:00'))
            expect(job.run_at.to_datetime).to eq dt('2014-03-09T11:00:00')
          end
        end

        it "handles daylight savings switches" do
          at '2014-03-08T12:00:00' do
            job = MyTask.schedule(run_at: dt('2014-03-08T11:00:00'), timezone: 'US/Pacific')
            expect(job.run_at.to_datetime).to eq dt('2014-03-09T10:00:00')
          end
        end

        it "takes timezone into account when specified in the class" do
          at '2014-03-08T12:00:00' do
            job = MyTaskWithZone.schedule(run_at: dt('2014-03-08T11:00:00'))
            expect(job.run_at.to_datetime).to eq dt('2014-03-09T10:00:00')
          end         
        end

        it 'can accept days of the week' do
          at '2014-06-30T07:00:00' do
            job = MyTask.schedule run_at: 'sunday 8:00am', timezone: 'US/Pacific', run_every: 1.week
            expect(job.run_at.to_datetime).to eq dt('2014-07-06T15:00:00')
          end
        end
      end

      context "on second execution" do
        it "schedules the job correctly" do
          at '2014-03-07T12:00:00' do
            MyTask.schedule(run_at: dt('2014-03-08T11:00:00'), timezone: 'US/Pacific')
          end

          jobs = Delayed::Job.all
          expect(jobs.count).to eq 1
          expect(jobs.first.run_at.to_datetime).to eq dt('2014-03-08T11:00:00')
          at '2014-03-08T11:30:00' do
            Delayed::Worker.new.work_off
          end

          jobs = Delayed::Job.all
          expect(jobs.count).to eq 1
          expect(jobs.first.run_at.to_datetime).to eq dt('2014-03-09T10:00:00')                   
        end
      end
    end

    context "multiple run_at times" do
      context "initially" do
        it "runs at the next occurrence of the specified time today" do
          at '2014-03-08T12:00:00' do
            job = MyTask.schedule(run_at: [dt('2014-03-08T04:00:00'), dt('2014-03-08T13:00:00')], timezone: 'US/Pacific')
            expect(job.run_at.to_datetime).to eq dt('2014-03-08T13:00:00')
          end
        end
        it "runs at the next occurrence of the specified time tomorrow" do
          at '2014-03-08T13:01:00' do
            job = MyTask.schedule(run_at: [dt('2014-03-08T04:00:00'), dt('2014-03-08T13:00:00')], timezone: 'US/Pacific')
            expect(job.run_at.to_datetime).to eq dt('2014-03-09T04:00:00')
          end
        end
        it "takes daylight savings into account" do
          at '2014-03-09T04:01:00' do
            job = MyTask.schedule(run_at: [dt('2014-03-08T04:00:00'), dt('2014-03-08T13:00:00')], timezone: 'US/Pacific')
            expect(job.run_at.to_datetime).to eq dt('2014-03-09T12:00:00')
          end
        end
        it "can parse time from a string" do
          at '2014-03-09T04:01:00' do
            job = MyTask.schedule(run_at: ['8:00pm', '5:00am'], timezone: 'US/Pacific')
            expect(job.run_at.to_datetime).to eq dt('2014-03-09T12:00:00')
          end
        end
      end

      context "on second execution" do
        it "schedules the job correctly" do
          at '2014-03-08T13:01:00' do
            MyTask.schedule(run_at: [dt('2014-03-08T04:00:00'), dt('2014-03-08T13:00:00')], timezone: 'US/Pacific')
          end

          jobs = Delayed::Job.all
          expect(jobs.count).to eq 1
          expect(jobs.first.run_at.to_datetime).to eq dt('2014-03-09T04:00:00')
          at '2014-03-09T04:30:00' do
            Delayed::Worker.new.work_off
          end

          jobs = Delayed::Job.all
          expect(jobs.count).to eq 1
          expect(jobs.first.run_at.to_datetime).to eq dt('2014-03-09T12:00:00')
        end
      end
    end

    context 'failing jobs' do
      let(:job) do
        Delayed::Job.all.tap { |jobs| expect(jobs.count).to eq 1 }.first
      end

      before do
        @prev_max_attempts = Delayed::Worker.max_attempts
        Delayed::Worker.max_attempts = max_attempts

        at '2014-03-08T11:59:59' do
          MyTaskThatFails.schedule(run_at: dt('2014-03-08T12:00:00'), timezone: 'US/Pacific')
        end
        at '2014-03-08T12:00:00' do
          Delayed::Worker.new.work_off
        end
      end

      after do
        Delayed::Worker.max_attempts = @prev_max_attempts 
      end

      context 'after all attempts have been exhausted' do
        let(:max_attempts) { 1 }
        it 'should still be rescheduled' do
          expect(job.attempts).to eq 0
          expect(job.run_at.to_datetime).to eq dt('2014-03-09T11:00:00')
        end
      end

      context 'with retries remaining' do
        let(:max_attempts) { 2 }
        it 'should not be rescheduled' do
          expect(job.attempts).to eq 1
          expect(job.run_at.to_datetime).to eq dt('2014-03-08T12:00:06') # delayed_job reschedules the job for (N**4 + 5) seconds in the future, N=1
        end
      end
    end

    context 'additional scheduled jobs being created while our job is running' do
      before do
        at '2014-03-08T11:59:59' do
          MySelfSchedulingTask.schedule(run_at: dt('2014-03-08T12:00:00'), timezone: 'US/Pacific')
        end
        at '2014-03-08T12:00:00' do
          Delayed::Worker.new.work_off
        end
      end

      it 'should not get scheduled more than once' do
        expect(MySelfSchedulingTask.jobs.count).to eq 1
      end
    end
  end

  describe '#schedule!' do
    it 'reschedules the job' do
      at '2014-03-08T01:00:00' do
        MyTask.schedule!(run_at: '3:00am', timezone: 'UTC')
        MyTask.schedule!(run_at: '2:00am', timezone: 'UTC')
      end
      jobs = Delayed::Job.all
      expect(jobs.count).to eq 1
      expect(jobs.first.run_at.to_datetime).to eq dt('2014-03-08T02:00:00')
    end
  end

  describe 'run_at' do
    it 'allows a single value' do
      MyTask1.run_at '1:00'
      expect(MyTask1.run_at).to eq ['1:00']
    end
    it 'allows multiple values' do
      MyTask2.run_at '1:00', '2:00'
      expect(MyTask2.run_at).to eq ['1:00', '2:00']
    end
    it 'can be called multiple times' do
      MyTask3.run_at '1:00'
      MyTask3.run_at '2:00'
      expect(MyTask2.run_at).to eq ['1:00', '2:00']
    end
  end

  describe 'priority' do
    it 'can be set in the class' do
      MyTaskWithPriority.schedule!
      jobs = Delayed::Job.all
      expect(jobs.count).to eq 1
      expect(jobs.first.priority).to eq 2
    end

    it 'can be set in options' do
      MyTaskWithPriority.schedule!(priority: 3)
      jobs = Delayed::Job.all
      expect(jobs.count).to eq 1
      expect(jobs.first.priority).to eq 3
    end
  end

  describe 'queue name' do
    it 'can be set in the class' do
      MyTaskWithQueueName.schedule!
      jobs = Delayed::Job.all
      expect(jobs.count).to eq 1
      expect(jobs.first.queue).to eq 'other-queue'
    end

    it 'can be set in options' do
      MyTaskWithQueueName.schedule!(queue: 'blarg')
      jobs = Delayed::Job.all
      expect(jobs.count).to eq 1
      expect(jobs.first.queue).to eq 'blarg'
    end

    it 'uses the default queue if not specified' do
      Delayed::Worker.default_queue_name = 'slow-jobs'
      MyTask.schedule!
      jobs = Delayed::Job.all
      expect(jobs.count).to eq 1
      expect(jobs.first.queue).to eq 'slow-jobs'
    end
  end

  describe '#scheduled?' do
    it "returns false initially" do
      expect(MyTask.scheduled?).to eq false
    end

    it "returns true after job has been scheduled" do
      MyTask.schedule
      expect(MyTask.scheduled?).to eq true
    end

    it "returns false if a similarly-named but different job has been scheduled" do
      MyTas.schedule
      expect(MyTask.scheduled?).to eq false
      expect(MyTas.scheduled?).to eq true
    end

    it "behaves correctly for classes with instance variables" do
      MyTaskWithIVars.schedule
      expect(MyTaskWithIVars.scheduled?).to eq true
    end

    it "behaves correctly for classes inside modules" do
      MyModule::MySubTask.schedule
      expect(MyModule::MySubTask.scheduled?).to eq true
    end
  end

  describe 'inheritance' do
    it "inherits properties of the parent class" do
      expect(SubTaskWithZone.run_every).to eq 1.day
      expect(SubTaskWithZone.timezone).to eq 'US/Pacific'
      expect(SubTaskWithZone.priority).to eq 0
    end

    it "can override properties of the parent class" do
      expect(SubTaskWithZone.run_at).to eq ['6:00am']
    end

    it "does not propagate overridden properties back to the parent" do
      expect(MyTaskWithZone.run_at).to eq ['5:00am']
    end
  end
end

def at(time, &block)
  Timecop.freeze(dt(time)) { block.call }
end

def dt(time)
  DateTime.parse(time)
end