# frozen_string_literal: true

require 'puppeteer'
require 'capybara'

require 'capybara/puppeteer/browser'
require 'capybara/puppeteer/driver'
require 'capybara/puppeteer/node'

Capybara.register_driver(:puppeteer) do |app|
  Capybara::Puppeteer::Driver.new(app, headless: false)
end
