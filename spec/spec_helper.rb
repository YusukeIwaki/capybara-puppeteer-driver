# frozen_string_literal: true

require 'bundler/setup'
require 'capybara/puppeteer'
require 'capybara/rspec'
require 'timeout'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.define_derived_metadata(file_path: %r(/spec/feature/)) do |metadata|
    metadata[:type] = :feature
  end

  config.define_derived_metadata(file_path: %r(/spec/capybara/)) do |metadata|
    metadata[:type] = :capybara
  end

  config.around(:each, type: :capybara) do |example|
    Timeout.timeout(15) { example.run }
  end
end

Capybara.register_driver(:puppeteer) do |app|
  driver_options = {}
  if ENV['CI']
    driver_options[:headless] = true
    driver_options[:executable_path] = ENV['CHROME_EXECUTABLE_PATH']
  else
    driver_options[:headless] = false
  end
  driver_options.compact!
  Capybara::Puppeteer::Driver.new(app, **driver_options)
end

Capybara.default_driver = :puppeteer
Capybara.save_path = 'tmp/capybara'
Capybara.server = :webrick
