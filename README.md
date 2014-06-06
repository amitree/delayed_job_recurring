# delayed\_job\_recurring

Extends delayed\_job to support recurring jobs.

## Usage

In your Gemfile:

```ruby
gem 'delayed_job_recurring'
```

Then define a task class:

```ruby
class MyTask
  include Delayed::RecurringJob
  run_every 1.day
  run_at DateTime.parse('2014-03-08 11:00:00 PST')
  timezone 'US/Pacific'
  def perform
    # Do some work here!
  end
end
```

And schedule it. In a rails app, you might put this in an initializer:

```ruby
MyTask.schedule # run every day at 11am Pacific time (accounting for daylight savings)
```

## Advanced usage

### Passing options to schedule

```ruby
MyTask.schedule(run_at: DateTime.parse('2014-03-08 11:00:00 PST'))
```

### Running at multiples times each day

```ruby
MyTask.schedule(run_every: 1.day, run_at: [DateTime.parse('2014-03-08 11:00:00 PST'), DateTime.parse('2014-03-08 18:00:00 PST')]
```
