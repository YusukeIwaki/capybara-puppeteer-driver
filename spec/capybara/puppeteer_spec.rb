# frozen_string_literal: true

require 'spec_helper'
require 'capybara/spec/spec_helper'

module TestSessions
  Puppeteer = Capybara::Session.new(:puppeteer, TestApp)
end

Capybara::SpecHelper.run_specs TestSessions::Puppeteer, 'Puppeteer' do |example|
  case example.metadata[:full_description]
  when /when details is toggled open and closed/
    pending "NoMethodError: undefined method `and' for #<Capybara::RSpecMatchers::Matchers::HaveSelector:0x00007f9bafd56900>"
  when /drag_to.*HTML5/, /Element#drop/
    skip 'not implemented'
  when /#fill_in should fill in a textarea in a reasonable time by default/
    skip 'puppeteer-ruby is not so fast'
  when /Capybara::Window#maximize/,
       /Capybara::Window#fullscreen/,
       /Capybara::Window#size should switch to original window if invoked not for current window/
    skip 'not supported in Puppeteer driver'
  end

  Capybara::SpecHelper.reset!
end
