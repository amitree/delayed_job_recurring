Gem::Specification.new do |s|
  s.name        = 'delayed_job_recurring'
  s.version     = '0.3.4'
  s.date        = Date.today.to_s
  s.summary     = "Recurring jobs for delayed_job"
  s.description = "Extends delayed_job to support recurring jobs, including timezone support"
  s.authors     = ["Tony Novak"]
  s.email       = 'engineering@amitree.com'
  s.files       = Dir.glob("{bin,lib}/**/*") + %w(LICENSE README.md)

  s.homepage    = 'https://github.com/amitree/delayed_job_recurring'
  s.license     = 'MIT'

  s.required_ruby_version = '~> 2.0'

  s.add_development_dependency 'rails'
  s.add_development_dependency 'rspec', '3.0.0'
  s.add_development_dependency 'rspec-rails', '3.0.1'
  s.add_development_dependency 'sqlite3', '~> 1.3'
  s.add_development_dependency 'database_cleaner', '~> 1.3'
  s.add_development_dependency 'timecop', '~> 0.7.1'

  s.add_runtime_dependency 'delayed_job', '>= 4.0'
  s.add_runtime_dependency 'delayed_job_active_record', '>= 4.0'
end
