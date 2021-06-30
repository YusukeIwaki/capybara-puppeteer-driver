# `puppeteer-ruby`-based driver for Capybara

Alternative headless-Chrome driver for Capybara, using [puppeteer-ruby](https://github.com/YusukeIwaki/puppeteer-ruby)

![image](https://github.com/YusukeIwaki/puppeteer-ruby/blob/main/puppeteer-ruby.png?raw=true)

```ruby
gem 'capybara-puppeteer-driver'
```

## Example

```ruby
require 'capybara/puppeteer'

# Setup
Capybara.register_driver(:puppeteer) do |app|
  Capybara::Puppeteer::Driver.new(app,
    executable_path: '/usr/bin/google-chrome', # specify the executable path of Google Chrome.
    headless: false, # optional. default: true (headless)
  )
end
Capybara.default_max_wait_time = 15
Capybara.default_driver = :puppeteer
Capybara.save_path = 'tmp/capybara'

# Run
Capybara.app_host = 'https://github.com'
visit '/'
fill_in('q', with: 'Capybara')
find('a[data-item-type="global_search"]').click

all('.repo-list-item').each do |li|
  puts li.all('a').first.text
end
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Capybara::Puppeteer project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/capybara-puppeteer-driver/blob/master/CODE_OF_CONDUCT.md).
