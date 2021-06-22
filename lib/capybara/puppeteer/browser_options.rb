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
        @options.select { |k, _| LAUNCH_PARAMS.include?(k) }.tap do |result|
          result[:default_viewport] ||= ::Puppeteer::Viewport.new(width: 1280, height: 720)
        end
      end
    end
  end
end
