require 'support/db'
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
