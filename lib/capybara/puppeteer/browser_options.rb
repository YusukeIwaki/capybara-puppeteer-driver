module Capybara
  module Puppeteer
    class BrowserOptions
      def initialize(options)
        @options = options
      end

      LAUNCH_PARAMS = {
        executable_path: nil,
        headless: nil,
      }.keys

      def value
        @options.select { |k, _| LAUNCH_PARAMS.include?(k) }
      end
    end
  end
end
