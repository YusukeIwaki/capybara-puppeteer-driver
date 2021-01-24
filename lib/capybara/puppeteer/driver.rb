class Capybara::Puppeteer::Driver < Capybara::Driver::Base
  extend Forwardable

  def initialize(app, options = {})
    @browser_options = {
      headless: options[:headless],
      executable_path: options[:executable_path],
    }
  end

  def browser
    @browser ||= create_browser
  end

  private def create_browser
    main = Process.pid
    at_exit do
      # Store the exit status of the test run since it goes away after calling the at_exit proc...
      @exit_status = $ERROR_INFO.status if $ERROR_INFO.is_a?(SystemExit)
      quit if Process.pid == main
      exit @exit_status if @exit_status # Force exit with stored status
    end

    ::Capybara::Puppeteer::Browser.new(self, @browser_options)
  end

  private def quit
    browser&.quit
  end

  # ref: https://github.com/teamcapybara/capybara/blob/master/lib/capybara/driver/base.rb
  def_delegator(:browser, :current_url)
  def_delegator(:browser, :visit)
  def_delegator(:browser, :refresh)
  def_delegator(:browser, :find_xpath)
  def_delegator(:browser, :find_css)
  def_delegator(:browser, :html)
  def_delegator(:browser, :go_back)
  def_delegator(:browser, :go_forward)
  def_delegator(:browser, :execute_script)
  def_delegator(:browser, :evaluate_script)
  def_delegator(:browser, :evaluate_async_script)
  def_delegator(:browser, :save_screenshot)
  def_delegator(:browser, :response_headers)
  def_delegator(:browser, :status_code)
  def_delegator(:browser, :send_keys)
  def_delegator(:browser, :switch_to_frame)
  def_delegator(:browser, :current_window_handle)
  def_delegator(:browser, :window_size)
  def_delegator(:browser, :resize_window_to)
  def_delegator(:browser, :maximize_window)
  def_delegator(:browser, :fullscreen_window)
  def_delegator(:browser, :close_window)
  def_delegator(:browser, :window_handles)
  def_delegator(:browser, :open_new_window)
  def_delegator(:browser, :switch_to_window)
  def_delegator(:browser, :no_such_window_error)
  def_delegator(:browser, :accept_modal)
  def_delegator(:browser, :dismiss_modal)
end
