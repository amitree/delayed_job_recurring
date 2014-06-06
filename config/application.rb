require File.expand_path('../boot', __FILE__)

require 'rails/all'

Bundler.require(:default, Rails.env)

module DelayedJobRecurring
  class Application < Rails::Application
    config.eager_load = false
  end
end
