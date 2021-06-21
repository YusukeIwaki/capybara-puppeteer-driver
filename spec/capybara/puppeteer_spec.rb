# frozen_string_literal: true

require 'spec_helper'
require 'capybara/spec/spec_helper'

module TestSessions
  Puppeteer = Capybara::Session.new(:puppeteer, TestApp)
end

Capybara::SpecHelper.run_specs TestSessions::Puppeteer, 'Puppeteer' do |example|
  case example.metadata[:full_description]
  when /Element#drop/
    pending 'not implemented'
  when /Capybara::Window#maximize/,
       /Capybara::Window#fullscreen/
    skip 'not supported in Puppeteer driver'
  end

  Capybara::SpecHelper.reset!
end