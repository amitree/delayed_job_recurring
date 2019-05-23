require 'date'

Gem::Specification.new do |s|
  s.name        = 'delayed_job_recurring'
  s.version     = '0.3.8'
  s.date        = Date.today.to_s
  s.summary     = "Recurring jobs for delayed_job"
  s.description = "Extends delayed_job to support recurring jobs, including timezone support"
  s.authors     = ["Tony Novak"]
  s.email       = 'engineering@amitree.com'
  s.files       = Dir.glob("{bin,lib}/**/*") + %w(LICENSE README.md)

  s.homepage    = 'https://github.com/amitree/delayed_job_recurring'
  s.license     = 'MIT'

  s.required_ruby_version = '> 1.9'

  s.add_development_dependency 'rails'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '3.6.0'
  s.add_development_dependency 'rspec-rails', '3.6.1'
  s.add_development_dependency 'sqlite3', '~> 1.3'
  s.add_development_dependency 'database_cleaner', '~> 1.3'
  s.add_development_dependency 'timecop', '~> 0.7.1'

  s.add_runtime_dependency 'delayed_job', '>= 3.0'
  s.add_runtime_dependency 'delayed_job_active_record'
  s.add_runtime_dependency 'fugit', '~> 1.2.1'
end
