require 'spec_helper'

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

class MyTaskThatFails < MyTask
  run_every 1.day
  def perform
    raise 'fail'
  end
end

class MyTaskWithZone < MyTask
  run_every 1.day
  timezone 'US/Pacific'
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

class MyTask1 < MyTask
end

class MyTask2 < MyTask
end

class MyTaskWithPriority < MyTask
  priority 2
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

  describe '#scheduled?' do
    it "returns false initially" do
      expect(MyTask.scheduled?).to eq false
    end

    it "returns true after job has been scheduled" do
      MyTask.schedule
      expect(MyTask.scheduled?).to eq true
    end

    it "returns false if a similarly-named but different job has been scheduled" do
      task_class = Delayed::Task.schedule('MyTas', run_every: 10.minutes, run_at: 1.minute.from_now) { }
      expect(MyTask.scheduled?).to eq false
      expect(task_class.scheduled?).to eq true
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
end

def at(time, &block)
  Timecop.freeze(dt(time)) { block.call }
end

def dt(time)
  DateTime.parse(time)
end