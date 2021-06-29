module Capybara
  module Puppeteer
    class Browser
      class NoSuchWindowError < StandardError ; end

      def initialize(driver:, puppeteer_browser:)
        @driver = driver
        @puppeteer_browser = puppeteer_browser
        @puppeteer_page = puppeteer_browser.pages.first || puppeteer_browser.new_page

        @puppeteer_browser.on('targetdestroyed') do |target|
          if target.type == 'page'
            if target.target_id == @puppeteer_page&.target_id
              @puppeteer_page = nil
            end
          end
        end
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

      private def find_with(query_method, query, **options)
        begin
          @puppeteer_page.capybara_current_frame.send(query_method, query).map do |el|
            Node.new(@driver, @puppeteer_page, el)
          end
        rescue => err
          # Navigation occured during finding Node.
          if err.message =~ /Cannot find context with specified id/
            return [] # Rely on Capybara's retry.
          end

          raise
        end
      end

      def find_xpath(query, **options)
        find_with(:Sx, query, **options)
      end

      def find_css(query, **options)
        find_with(:query_selector_all, query, **options)
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

      def execute_script(script, *args)
        @puppeteer_page.capybara_current_frame.evaluate("function () { #{script} }", *unwrap_node(args))
        nil
      end

      def evaluate_script(script, *args)
        result = @puppeteer_page.capybara_current_frame.evaluate_handle("function () { return #{script} }", *unwrap_node(args))
        wrap_node(result)
      end

      def evaluate_async_script(script, *args)
        js = <<~JAVASCRIPT
        function(){
          let args = Array.prototype.slice.call(arguments);
          return new Promise((resolve, reject) => {
            args.push(resolve);
            (function(){ #{script} }).apply(this, args);
          });
        }
        JAVASCRIPT
        result = @puppeteer_page.capybara_current_frame.evaluate_handle(js, *unwrap_node(args))
        wrap_node(result)
      end

      def send_keys(*args)
        Node::SendKeys.new(@puppeteer_page.keyboard, @puppeteer_page.keyboard, args).execute
      end

      def save_screenshot(path, **options)
        @puppeteer_page.screenshot(path: path)
      end

      def switch_to_frame(frame)
        case frame
        when :top
          @puppeteer_page.capybara_reset_frames
        when :parent
          @puppeteer_page.capybara_pop_frame
        else
          puppeteer_frame = frame.native.content_frame
          raise ArgumentError.new("Not a frame element: #{frame}") unless puppeteer_frame
          @puppeteer_page.capybara_push_frame(puppeteer_frame)
        end
      end

      def window_handles
        @puppeteer_browser.pages.map(&:capybara_id)
      end

      def current_window_handle
        @puppeteer_page&.capybara_id
      end

      def open_new_window(kind = :tab)
        @puppeteer_browser.new_page
      end

      private def on_window(handle, &block)
        page = @puppeteer_browser.pages.find { |page| page.capybara_id == handle }
        if page
          block.call(page)
        else
          raise NoSuchWindowError
        end
      end

      def switch_to_window(handle)
        return if @puppeteer_page&.capybara_id == handle

        on_window(handle) do |page|
          @puppeteer_page = page.tap(&:bring_to_front)
        end
      end

      def close_window(handle)
        on_window(handle) do |page|
          page.close
        end

        if @puppeteer_page&.capybara_id == handle
          @puppeteer_page = nil
        end
      end

      def accept_modal(dialog_type, **options, &block)
        @puppeteer_page.capybara_accept_modal(dialog_type, **options, &block)
      end

      def dismiss_modal(dialog_type, **options, &block)
        @puppeteer_page.capybara_dismiss_modal(dialog_type, **options, &block)
      end

      private def capybara_default_wait_time
        Capybara.default_max_wait_time * 1000
      end

      private def unwrap_node(args)
        args.map do |arg|
          if arg.is_a?(Node)
            arg.native
          else
            arg
          end
        end
      end

      private def wrap_node(arg)
        case arg
        when Array
          arg.map do |item|
            wrap_node(item)
          end
        when Hash
          arg.map do |key, value|
            [key, wrap_node(value)]
          end.to_h
        when ::Puppeteer::ElementHandle
          Node.new(@driver, @puppeteer_page, arg)
        when ::Puppeteer::JSHandle
          obj_type, is_array = arg.evaluate('obj => [typeof obj, Array.isArray(obj)]')
          if obj_type == 'object'
            if is_array
              arg.properties.map do |_, value|
                wrap_node(value)
              end
            else
              arg.properties.map do |key, value|
                [key, wrap_node(value)]
              end.to_h
            end
          else
            arg.json_value
          end
        else
          arg
        end
      end
    end
  end
end
