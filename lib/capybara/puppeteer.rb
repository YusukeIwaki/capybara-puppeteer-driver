# frozen_string_literal: true

require 'puppeteer'
require 'capybara'

Capybara.register_driver(:puppeteer) do |app|
  Capybara::Puppeteer::Driver.new(app)
end
