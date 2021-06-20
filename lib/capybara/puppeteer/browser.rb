module Capybara
  module Puppeteer
    class Browser
      class NoSuchWindowError < StandardError ; end

      def initialize(driver:, puppeteer_browser:)
        @driver = driver
        @puppeteer_browser = puppeteer_browser
        @puppeteer_page = puppeteer_browser.pages.first || puppeteer_browser.new_page
      end

      def current_url
        @puppeteer_page.url
      end

      def visit(path)
        url =
        if Capybara.app_host
          URI(Capybara.app_host).merge(path)
        elsif Capybara.default_host
          URI(Capybara.default_host).merge(path)
        else
          path
        end

        @puppeteer_page.capybara_current_frame.goto(url)
      end

      def refresh
        @puppeteer_page.capybara_current_frame.evaluate('() => { location.reload(true) }')
      end

      def find_xpath(query, **options)
        @puppeteer_page.capybara_current_frame.wait_for_xpath(query, visible: true, timeout: capybara_default_wait_time)
        @puppeteer_page.capybara_current_frame.Sx(query).map do |el|
          Node.new(@driver, @puppeteer_page, el)
        end
      end

      def find_css(query, **options)
        @puppeteer_page.capybara_current_frame.wait_for_selector(query, visible: true, timeout: capybara_default_wait_time)
        @puppeteer_page.capybara_current_frame.SS(query).map do |el|
          Node.new(@driver, @puppeteer_page, el)
        end
      end

      def response_headers
        @puppeteer_page.capybara_response_headers
      end

      def status_code
        @puppeteer_page.capybara_status_code
      end

      def html
        js = <<~JAVASCRIPT
        () => {
          let html = '';
          if (document.doctype) html += new XMLSerializer().serializeToString(document.doctype);
          if (document.documentElement) html += document.documentElement.outerHTML;
          return html;
        }
        JAVASCRIPT
        @puppeteer_page.capybara_current_frame.evaluate(js)
      end

      def title
        @puppeteer_page.title
      end

      def go_back
        @puppeteer_page.go_back
      end

      def go_forward
        @puppeteer_page.go_forward
      end

      def save_screenshot(path, **options)
        @puppeteer_page.screenshot(path: path)
      end

      private def capybara_default_wait_time
        Capybara.default_max_wait_time * 1000
      end
    end
  end
end
