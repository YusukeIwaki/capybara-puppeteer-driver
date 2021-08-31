[![Gem Version](https://badge.fury.io/rb/capybara-puppeteer-driver.svg)](https://badge.fury.io/rb/capybara-puppeteer-driver)

**IMPORTANT**

This Gem is just my hobby work and **not production-ready** at this moment.

If you really want to use Puppeteer with Capybara, refer this guide at first:
[Use Puppeteer methods simply without Capybara::DSL](https://github.com/YusukeIwaki/puppeteer-ruby#bulb-use-puppeteer-methods-simply-without-capybaradsl)

It is STRONGLY encouraged to use Puppeteer without this driver or Capybara DSL because useful methods of Puppeteer (such as `Page#wait_for_selector` or `Page#wait_for_navigation`) are unavailable via Capybara DSL.

---

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
    # Specify browser type.
    # Either of 'chrome', 'chrome-beta', 'chrome-canary', 'chrome-dev', 'msedge'.
    # chrome is used by default.
    channel: 'msedge',
    # Or specify the executable path of Google Chrome.
    # Useful option for Docker integration.
    # When channel is specified, executable_path is ignored.
    executable_path: '/usr/bin/google-chrome',

    # `headless: false` -> headful mode.
    # `headless: true` -> headless mode. (default)
    headless: false,
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
