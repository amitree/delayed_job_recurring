# delayed\_job\_recurring
[![Build Status](https://travis-ci.org/amitree/delayed_job_recurring.svg)](https://travis-ci.org/amitree/delayed_job_recurring)

Extends delayed\_job to support recurring jobs.

## Usage

Add it to your Gemfile:

```ruby
gem 'delayed_job_recurring'
```

Then define a task class.  We like the concept of
[interactors](http://eng.joingrouper.com/blog/2014/03/03/rails-the-missing-parts-interactors),
so we put our task classes in `app/interactors`.  You could also put them in `lib` or even `app/models`.

```ruby
class MyTask
  include Delayed::RecurringJob
  run_every 1.day
  run_at '11:00am'
  timezone 'US/Pacific'
  queue 'slow-jobs'
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
MyTask.schedule(run_at: '12:00')
```

### Running at multiples times each day

```ruby
MyTask.schedule(run_every: 1.day, run_at: ['11:00', '6:00pm']
```

### Running on specific days of the week

```ruby
MyTask.schedule(run_every: 1.week, run_at: ['sunday 8:00am', 'wednesday 8:00am'])
```

## Thanks!

Many thanks to @ginjo and @kares for their work!  This code was derived from https://gist.github.com/ginjo/3688965.
