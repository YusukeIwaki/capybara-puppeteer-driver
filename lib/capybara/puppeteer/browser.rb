class Capybara::Puppeteer::Browser
  def initialize(driver, options)
    @driver = driver

    headless = options[:headless] != false
    executable_path = options[:executable_path]
    browser = Puppeteer.launch(
      headless: headless,
      executable_path: executable_path,
    )
    page = browser.pages.first || browser.new_page

    @puppeteer_browser = browser
    @puppeteer_page = page
  end

  def quit
    @puppeteer_browser.close
  end

  def visit(path)
    url =
      if Capybara.app_host
        URI(Capybara.app_host).merge(path)
      else
        path
      end

    @puppeteer_page.goto(url)
  end

  def refresh
    @puppeteer_page.evaluate('() => { location.reload(true) }')
  end

  def find_xpath(query, **options)
    @puppeteer_page.wait_for_xpath(query, visible: true, timeout: Capybara.default_max_wait_time * 1000)
    @puppeteer_page.Sx(query).map do |el|
      ::Capybara::Puppeteer::Node.new(@driver, @puppeteer_page, el)
    end
  end

  def find_css(query, **options)
    @puppeteer_page.wait_for_selector(query, visible: true, timeout: Capybara.default_max_wait_time * 1000)
    @puppeteer_page.SS(query).map do |el|
      ::Capybara::Puppeteer::Node.new(@driver, @puppeteer_page, el)
    end
  end

  def save_screenshot(path, **options)
    @puppeteer_page.screenshot(path: path)
  end
end
