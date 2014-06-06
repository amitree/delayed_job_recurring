ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
ActiveRecord::Tasks::DatabaseTasks.load_schema

require 'database_cleaner'
require 'timecop'

DatabaseCleaner.strategy = :transaction
RSpec.configure do |config|
  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
