# delayed\_job\_recurring

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

## Thanks!

Many thanks to @ginjo and @kares for their work!  This code was derived from https://gist.github.com/ginjo/3688965.
