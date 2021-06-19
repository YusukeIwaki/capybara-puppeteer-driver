# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'capybara/puppeteer/version'

Gem::Specification.new do |spec|
  spec.name          = 'capybara-puppeteer-driver'
  spec.version       = Capybara::Puppeteer::VERSION
  spec.authors       = ['YusukeIwaki']
  spec.email         = ['q7w8e9w8q7w8e9@yahoo.co.jp']

  spec.summary       = 'Headless Chrome driver for Capybara using puppeteer-ruby'
  spec.homepage      = 'https://github.com/YusukeIwaki/capybara-puppeteer-driver'
  spec.license       = 'MIT'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'capybara'
  spec.add_dependency 'puppeteer-ruby', '>= 0.32.3'
  spec.add_development_dependency 'bundler', '~> 2.2.3'
  spec.add_development_dependency 'launchy', '>= 2.0.4'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rake', '~> 13.0.3'
  spec.add_development_dependency 'rspec', '~> 3.10.0'
  spec.add_development_dependency 'rubocop-rspec'
  spec.add_development_dependency 'sinatra', '>= 1.4.0'
  spec.add_development_dependency 'webrick'
end
