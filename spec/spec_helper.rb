# frozen_string_literal: true

require 'bundler/setup'
require 'capybara/puppeteer'
require 'capybara/rspec'

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

  config.around(:each) do |example|
    require 'timeout'
    Timeout.timeout(15) { example.run }
  end
end

Capybara.register_driver(:puppeteer) do |app|
  Capybara::Puppeteer::Driver.new(app, headless: ENV['CI'] ? true : false)
end

Capybara.default_driver = :puppeteer
Capybara.save_path = 'tmp/capybara'
Capybara.server = :webrick
