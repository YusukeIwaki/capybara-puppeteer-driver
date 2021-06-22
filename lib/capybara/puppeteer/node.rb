module Capybara
  module Puppeteer
    module FramePatch
      def frame_element(frame_id)
        result = @client.send_message('DOM.getFrameOwner', frameId: frame_id)
        execution_context.adopt_backend_node_id(result['backendNodeId'])
      end
    end
    ::Puppeteer::Frame.prepend(FramePatch)

    module ElementHandlePatch
      def select_all
        evaluate(<<~JAVASCRIPT)
        element => {
          if (element.select) {
            element.select();
          } else {
            const range = document.createRange();
            range.selectNodeContents(element);
            window.getSelection().removeAllRanges();
            window.getSelection().addRange(range);
          }
        }
        JAVASCRIPT
      end

      def click(position: nil, delay: nil, button: nil, click_count: nil)
        if position
          click_with_offset(
            x: position[:x],
            y: position[:y],
            delay: delay,
            button: button,
            click_count: click_count,
          )
        else
          super(
            delay: delay,
            button: button,
            click_count: click_count,
          )
        end
      end

      def click_with_offset(x:, y:, delay: nil, button: nil, click_count: nil)
        scroll_into_view_if_needed
        box = bounding_box
        # FIXME: consider border.
        # https://github.com/microsoft/playwright/blob/af18b314730fbcb387be62d2bbf757b5cdda5f96/src/server/dom.ts#L278
        @page.mouse.click(box.x + x, box.y + y, delay: delay, button: button, click_count: click_count)
      end

      # likely to type_text, except for overwriting the input instead of inserting.
      def fill_text(text, delay: nil)
        click # #focus is not enough for executing selectAll against ContentEditable.
        select_all
        if !text || text.empty?
          @page.keyboard.press('Delete', delay: delay)
        else
          @page.keyboard.type_text(text, delay: delay)
        end
      end

      def owner_frame
        doc_handle = evaluate_handle(<<~JAVASCRIPT)
        node => {
          if (node.documentElement && node.documentElement.ownerDocument === node)
            return node.documentElement;
          else
            return node.ownerDocument ? node.ownerDocument.documentElement : null;
        }
        JAVASCRIPT

        frame = doc_handle&.content_frame
        doc_handle&.dispose
        frame
      end

      # ref: https://github.com/teamcapybara/capybara/blob/f7ab0b5cd5da86185816c2d5c30d58145fe654ed/lib/capybara/selenium/node.rb#L523
      OBSCURED_OR_OFFSET_SCRIPT = <<~JAVASCRIPT
      (el, x, y) => {
        var box = el.getBoundingClientRect();
        if (!x && x != 0) x = box.width / 2;
        if (!y && y != 0) y = box.height / 2;
        var px = box.left + x,
            py = box.top + y,
            e = document.elementFromPoint(px, py);
        if (!el.contains(e))
          return true;
        return { x: px, y: py };
      }
      JAVASCRIPT

      def capybara_obscured?(x: nil, y: nil)
        res = evaluate(OBSCURED_OR_OFFSET_SCRIPT, x, y)
        return true if res == true

        # ref: https://github.com/teamcapybara/capybara/blob/f7ab0b5cd5da86185816c2d5c30d58145fe654ed/lib/capybara/selenium/driver.rb#L182
        frame = owner_frame
        return false unless frame&.parent_frame
        frame.parent_frame.frame_element(frame.id).capybara_obscured?(x: res['x'], y: res['y'])
      end
    end
    ::Puppeteer::ElementHandle.prepend(ElementHandlePatch)

    # ref:
    #   selenium:   https://github.com/teamcapybara/capybara/blob/master/lib/capybara/selenium/node.rb
    #   apparition: https://github.com/twalpole/apparition/blob/master/lib/capybara/apparition/node.rb
    class Node < ::Capybara::Driver::Node
      class StaleReferenceError < StandardError ; end

      def initialize(driver, page, element)
        super(driver, element)
        @page = page
        @element = element
      end

      def all_text
        text = @element.evaluate('(el) => el.textContent')
        text.to_s.gsub(/[\u200b\u200e\u200f]/, '')
            .gsub(/[\ \n\f\t\v\u2028\u2029]+/, ' ')
            .gsub(/\A[[:space:]&&[^\u00a0]]+/, '')
            .gsub(/[[:space:]&&[^\u00a0]]+\z/, '')
            .tr("\u00a0", ' ')
      end

      def visible_text
        return '' unless visible?

        text = @element.evaluate(<<~JAVASCRIPT)
          function(el){
            if (el.nodeName == 'TEXTAREA'){
              return el.textContent;
            } else if (el instanceof SVGElement) {
              return el.textContent;
            } else {
              return el.innerText;
            }
          }
        JAVASCRIPT
        text.to_s.gsub(/\A[[:space:]&&[^\u00a0]]+/, '')
            .gsub(/[[:space:]&&[^\u00a0]]+\z/, '')
            .gsub(/\n+/, "\n")
            .tr("\u00a0", ' ')
      end

      def [](name)
        property(name) || attribute(name)
      end

      private def property(name)
        @element.evaluate(<<~JAVASCRIPT)
        (el, name) => {
          const value = el[name];
          if (['object', 'function'].includes(typeof value)) {
            return null;
          } else {
            return value;
          }
        }
        JAVASCRIPT
      end

      private def attribute(name)
        @element.evaluate('(el, name) => el.getAttribute(name)', name)
      end

      def value
        # ref: https://github.com/teamcapybara/capybara/blob/f7ab0b5cd5da86185816c2d5c30d58145fe654ed/lib/capybara/selenium/node.rb#L31
        # ref: https://github.com/twalpole/apparition/blob/11aca464b38b77585191b7e302be2e062bdd369d/lib/capybara/apparition/node.rb#L728
        if tag_name == 'select' && @element.evaluate('el => el.multiple')
          @element.query_selector_all('option:checked').map do |option|
            option.evaluate('el => el.value')
          end
        else
          @element.evaluate('el => el.value')
        end
      end

      def style(styles)
        raise NotImplementedError
      end

      # @param value [String, Array] Array is only allowed if node has 'multiple' attribute
      # @param options [Hash] Driver specific options for how to set a value on a node
      def set(value, **options)
        settable_class =
          case tag_name
          when 'input'
            case attribute('type')
            when 'radio'
              RadioButton
            when 'checkbox'
              Checkbox
            when 'file'
              FileUpload
            when 'date'
              DateInput
            when 'time'
              TimeInput
            when 'datetime-local'
              DateTimeInput
            when 'color'
              JSValueInput
            when 'range'
              JSValueInput
            else
              TextInput
            end
          when 'textarea'
            TextInput
          else
            if @element['isContentEditable']
              TextInput
            else
              raise NotSupportedByDriverError
            end
          end

        settable_class.new(@element, capybara_default_wait_time).set(value, **options)
      end

      class Settable
        def initialize(element, timeout)
          @element = element
          @timeout = timeout
        end
      end

      class RadioButton < Settable
        def set(_, **options)
          @element.check(timeout: @timeout)
        end
      end

      class Checkbox < Settable
        def set(value, **options)
          if value
            @element.check(timeout: @timeout)
          else
            @element.uncheck(timeout: @timeout)
          end
        end
      end

      class TextInput < Settable
        def set(value, **options)
          @element.fill_text(value.to_s)
        end
      end

      class FileUpload < Settable
        def set(value, **options)
          @element.set_input_files(value, timeout: @timeout)
        end
      end

      module UpdateValueJS
        def update_value_js(element, value)
          # ref: https://github.com/teamcapybara/capybara/blob/f7ab0b5cd5da86185816c2d5c30d58145fe654ed/lib/capybara/selenium/node.rb#L343
          js = <<~JAVASCRIPT
          (el, value) => {
            if (el.readOnly) { return };
            if (document.activeElement !== el){
              el.focus();
            }
            if (el.value != value) {
              el.value = value;
              el.dispatchEvent(new InputEvent('input'));
              el.dispatchEvent(new Event('change', { bubbles: true }));
            }
          }
          JAVASCRIPT
          element.evaluate(js, arg: value)
        end
      end

      class DateInput < Settable
        include UpdateValueJS

        def set(value, **options)
          if !value.is_a?(String) && value.respond_to?(:to_date)
            update_value_js(@element, value.to_date.iso8601)
          else
            @element.fill_text(value.to_s, timeout: @timeout)
          end
        end
      end

      class TimeInput < Settable
        include UpdateValueJS

        def set(value, **options)
          if !value.is_a?(String) && value.respond_to?(:to_time)
            update_value_js(@element, value.to_time.strftime('%H:%M'))
          else
            @element.fill_text(value.to_s, timeout: @timeout)
          end
        end
      end

      class DateTimeInput < Settable
        include UpdateValueJS

        def set(value, **options)
          if !value.is_a?(String) && value.respond_to?(:to_time)
            update_value_js(@element, value.to_time.strftime('%Y-%m-%dT%H:%M'))
          else
            @element.fill_text(value.to_s, timeout: @timeout)
          end
        end
      end

      class JSValueInput < Settable
        include UpdateValueJS

        def set(value, **options)
          update_value_js(@element, value)
        end
      end

      def select_option
        raise NotImplementedError
      end

      def unselect_option
        raise NotImplementedError
      end

      def click(keys = [], **options)
        click_options = ClickOptions.new(@element, keys, options)
        params = click_options.as_params
        click_options.with_modifiers_pressing(@page.keyboard) do
          @element.click(**params)
        end
      end

      def right_click(keys = [], **options)
        click_options = ClickOptions.new(@element, keys, options)
        params = click_options.as_params
        params[:button] = 'right'
        click_options.with_modifiers_pressing(@page.keyboard) do
          @element.click(**params)
        end
      end

      def double_click(keys = [], **options)
        click_options = ClickOptions.new(@element, keys, options)
        params = click_options.as_params
        params[:click_count] = 2
        click_options.with_modifiers_pressing(@page.keyboard) do
          @element.click(**params)
        end
      end

      class ClickOptions
        MODIFIERS = {
          alt: 'Alt',
          ctrl: 'Control',
          control: 'Control',
          meta: 'Meta',
          command: 'Meta',
          cmd: 'Meta',
          shift: 'Shift',
        }.freeze

        def initialize(element, keys, options)
          @element = element
          @modifiers = keys.map do |key|
            MODIFIERS[key.to_sym] or raise ArgumentError.new("Unknown modifier key: #{key}")
          end
          if options[:x] && options[:y]
            @coords = {
              x: options[:x],
              y: options[:y],
            }
            @offset_center = options[:offset] == :center
          end
          @delay = options[:delay]
        end

        def as_params
          {
            delay: delay_ms,
            position: position,
          }.compact
        end

        def with_modifiers_pressing(keyboard, &block)
          @modifiers.each { |key| keyboard.down(key) }
          block.call
          @modifiers.each { |key| keyboard.up(key) }
        end

        private def delay_ms
          if @delay && @delay > 0
            @delay * 1000
          else
            nil
          end
        end

        private def position
          if @offset_center
            box = @element.bounding_box

            {
              x: @coords[:x] + box.width / 2,
              y: @coords[:y] + box.height / 2,
            }
          else
            @coords
          end
        end
      end

      def send_keys(*args)
        SendKeys.new(@element, @page.keyboard, args).execute
      end

      class SendKeys
        MODIFIERS = {
          alt: 'Alt',
          ctrl: 'Control',
          control: 'Control',
          meta: 'Meta',
          command: 'Meta',
          cmd: 'Meta',
          shift: 'Shift',
        }.freeze

        KEYS = {
          cancel: 'Cancel',
          help: 'Help',
          backspace: 'Backspace',
          tab: 'Tab',
          clear: 'Clear',
          return: 'Enter',
          enter: 'Enter',
          shift: 'Shift',
          control: 'Control',
          alt: 'Alt',
          pause: 'Pause',
          escape: 'Escape',
          space: 'Space',
          page_up: 'PageUp',
          page_down: 'PageDown',
          end: 'End',
          home: 'Home',
          left: 'ArrowLeft',
          up: 'ArrowUp',
          right: 'ArrowRight',
          down: 'ArrowDown',
          insert: 'Insert',
          delete: 'Delete',
          semicolon: 'Semicolon',
          equals: 'Equal',
          numpad0: 'Numpad0',
          numpad1: 'Numpad1',
          numpad2: 'Numpad2',
          numpad3: 'Numpad3',
          numpad4: 'Numpad4',
          numpad5: 'Numpad5',
          numpad6: 'Numpad6',
          numpad7: 'Numpad7',
          numpad8: 'Numpad8',
          numpad9: 'Numpad9',
          multiply: 'NumpadMultiply',
          add: 'NumpadAdd',
          separator: 'NumpadDecimal',
          subtract: 'NumpadSubtract',
          decimal: 'NumpadDecimal',
          divide: 'NumpadDivide',
          f1: 'F1',
          f2: 'F2',
          f3: 'F3',
          f4: 'F4',
          f5: 'F5',
          f6: 'F6',
          f7: 'F7',
          f8: 'F8',
          f9: 'F9',
          f10: 'F10',
          f11: 'F11',
          f12: 'F12',
          meta: 'Meta',
          command: 'Meta',
        }

        def initialize(element_or_keyboard, keyboard, keys)
          @element_or_keyboard = element_or_keyboard
          @keyboard = keyboard

          holding_keys = []
          @executables = keys.each_with_object([]) do |key, executables|
            if MODIFIERS[key]
              holding_keys << key
            else
              if holding_keys.empty?
                case key
                when String
                  executables << TypeText.new(key)
                when Symbol
                  executables << PressKey.new(
                    keyboard: @keyboard,
                    key: key_for(key),
                    modifiers: [],
                  )
                when Array
                  _key = key.last
                  code =
                    if _key.is_a?(String) && _key.length == 1
                      _key.upcase
                    elsif _key.is_a?(Symbol)
                      key_for(_key)
                    else
                      raise ArgumentError.new("invalid key: #{_key}. Symbol of 1-length String is expected.")
                    end
                  modifiers = key.first(key.size - 1).map { |k| modifier_for(k) }
                  executables << PressKey.new(
                    keyboard: @keyboard,
                    key: code,
                    modifiers: modifiers,
                  )
                end
              else
                modifiers = holding_keys.map { |k| modifier_for(k) }

                case key
                when String
                  key.each_char do |char|
                    executables << PressKey.new(
                      keyboard: @keyboard,
                      key: char.upcase,
                      modifiers: modifiers,
                    )
                  end
                when Symbol
                  executables << PressKey.new(
                    keyboard: @keyboard,
                    key: key_for(key),
                    modifiers: modifiers
                  )
                else
                  raise ArgumentError.new("#{key} cannot be handled with holding key #{holding_keys}")
                end
              end
            end
          end
        end

        private def modifier_for(modifier)
          MODIFIERS[modifier] or raise ArgumentError.new("invalid modifier specified: #{modifier}")
        end

        private def key_for(key)
          KEYS[key] or raise ArgumentError.new("invalid key specified: #{key}")
        end

        def execute
          @executables.each do |executable|
            executable.execute_for(@element_or_keyboard)
          end
        end

        class PressKey
          def initialize(keyboard:, key:, modifiers:)
            # puts "PressKey: key=#{key} modifiers: #{modifiers}"
            @keyboard = keyboard
            @modifiers = modifiers
          end

          def execute_for(element)
            with_modifiers_pressing do
              element.press(@key)
            end
          end

          private def with_modifiers_pressing(&block)
            @modifiers.each { |key| @keyboard.down(key) }
            block.call
            @modifiers.each { |key| @keyboard.up(key) }
          end
        end

        class TypeText
          def initialize(text)
            @text = text
          end

          def execute_for(element)
            element.type(@text)
          end
        end
      end

      def hover
        @element.hover
      end

      def drag_to(element, **options)
        DragTo.new(@page, @element, element.native, options).execute
      end

      class DragTo
        MODIFIERS = {
          alt: 'Alt',
          ctrl: 'Control',
          control: 'Control',
          meta: 'Meta',
          command: 'Meta',
          cmd: 'Meta',
          shift: 'Shift',
        }.freeze

        # @param page [Playwright::Page]
        # @param source [Playwright::ElementHandle]
        # @param target [Playwright::ElementHandle]
        def initialize(page, source, target, options)
          @page = page
          @source = source
          @target = target
          @options = options
        end

        def execute
          @source.scroll_into_view_if_needed

          # down
          position_from = center_of(@source)
          @page.mouse.move(*position_from)
          @page.mouse.down

          @target.scroll_into_view_if_needed

          # move and up
          sleep_delay
          position_to = center_of(@target)
          with_key_pressing(drop_modifiers) do
            @page.mouse.move(*position_to, steps: 6)
            sleep_delay
            @page.mouse.up
          end
          sleep_delay
        end

        # @param element [Playwright::ElementHandle]
        private def center_of(element)
          box = element.bounding_box
          [box.x + box.width / 2, box.y + box.height / 2]
        end

        private def with_key_pressing(keys, &block)
          keys.each { |key| @page.keyboard.down(key) }
          block.call
          keys.each { |key| @page.keyboard.up(key) }
        end

        # @returns Array<String>
        private def drop_modifiers
          return [] unless @options[:drop_modifiers]

          Array(@options[:drop_modifiers]).map do |key|
            MODIFIERS[key.to_sym]  or raise ArgumentError.new("Unknown modifier key: #{key}")
          end
        end

        private def sleep_delay
          return unless @options[:delay]

          sleep @options[:delay]
        end
      end

      def drop(*args)
        raise NotImplementedError
      end

      def scroll_by(x, y)
        js = <<~JAVASCRIPT
        (el, x, y) => {
          if (el.scrollBy){
            el.scrollBy(x, y);
          } else {
            el.scrollTop = el.scrollTop + y;
            el.scrollLeft = el.scrollLeft + x;
          }
        }
        JAVASCRIPT

        @element.evaluate(js, x, y)
      end

      def scroll_to(element, location, position = nil)
        # location, element = element, nil if element.is_a? Symbol
        if element.is_a?(Capybara::Puppeteer::Node)
          scroll_element_to_location(element, location)
        elsif location.is_a?(Symbol)
          scroll_to_location(location)
        else
          scroll_to_coords(*position)
        end

        self
      end

      private def scroll_element_to_location(element, location)
        scroll_opts =
          case location
          when :top
            'true'
          when :bottom
            'false'
          when :center
            "{behavior: 'instant', block: 'center'}"
          else
            raise ArgumentError, "Invalid scroll_to location: #{location}"
          end

        element.native.evaluate("(el) => { el.scrollIntoView(#{scroll_opts}) }")
      end

      SCROLL_POSITIONS = {
        top: '0',
        bottom: 'el.scrollHeight',
        center: '(el.scrollHeight - el.clientHeight)/2'
      }.freeze

      private def scroll_to_location(location)
        position = SCROLL_POSITIONS[location]

        @element.evaluate(<<~JAVASCRIPT)
        (el) => {
          if (el.scrollTo){
            el.scrollTo(0, #{position});
          } else {
            el.scrollTop = #{position};
          }
        }
        JAVASCRIPT
      end

      private def scroll_to_coords(x, y)
        js = <<~JAVASCRIPT
        (el, x, y) => {
          if (el.scrollTo){
            el.scrollTo(x, y);
          } else {
            el.scrollTop = y;
            el.scrollLeft = x;
          }
        }
        JAVASCRIPT

        @element.evaluate(js, x, y)
      end

      def tag_name
        @tag_name ||= @element.evaluate('e => e.tagName.toLowerCase()')
      end

      def visible?
        # if an area element, check visibility of relevant image
        @element.evaluate(<<~JAVASCRIPT)
        function(el) {
          if (el.tagName == 'AREA'){
            const map_name = document.evaluate('./ancestor::map/@name', el, null, XPathResult.STRING_TYPE, null).stringValue;
            el = document.querySelector(`img[usemap='#${map_name}']`);
            if (!el){
            return false;
            }
          }
          var forced_visible = false;
          while (el) {
            const style = window.getComputedStyle(el);
            if (style.visibility == 'visible')
              forced_visible = true;
            if ((style.display == 'none') ||
                ((style.visibility == 'hidden') && !forced_visible) ||
                (parseFloat(style.opacity) == 0)) {
              return false;
            }
            var parent = el.parentElement;
            if (parent && (parent.tagName == 'DETAILS') && !parent.open && (el.tagName != 'SUMMARY')) {
              return false;
            }
            el = parent;
          }
          return true;
        }
        JAVASCRIPT
      end

      def obscured?
        @element.capybara_obscured?
      end

      def checked?
        @element.evaluate('el => !!el.checked')
      end

      def selected?
        @element.evaluate('el => !!el.selected')
      end

      def disabled?
        @element.evaluate(<<~JAVASCRIPT)
        function(el) {
          const xpath = 'parent::optgroup[@disabled] | \
                        ancestor::select[@disabled] | \
                        parent::fieldset[@disabled] | \
                        ancestor::*[not(self::legend) or preceding-sibling::legend][parent::fieldset[@disabled]]';
          return el.disabled || document.evaluate(xpath, el, null, XPathResult.BOOLEAN_TYPE, null).booleanValue
        }
        JAVASCRIPT
      end

      def readonly?
        @element.evaluate('el => el.readonly')
      end

      def multiple?
        @element.evaluate('el => el.multiple')
      end

      def rect
        @element.evaluate(<<~JAVASCRIPT)
        function(el){
          const rects = [...el.getClientRects()]
          const rect = rects.find(r => (r.height && r.width)) || el.getBoundingClientRect();
          return rect.toJSON();
        }
        JAVASCRIPT
      end

      def path
        @element.evaluate(<<~JAVASCRIPT)
        (el) => {
          var xml = document;
          var xpath = '';
          var pos, tempitem2;
          if (el.getRootNode && el.getRootNode() instanceof ShadowRoot) {
            return "(: Shadow DOM element - no XPath :)";
          };
          while(el !== xml.documentElement) {
            pos = 0;
            tempitem2 = el;
            while(tempitem2) {
              if (tempitem2.nodeType === 1 && tempitem2.nodeName === el.nodeName) { // If it is ELEMENT_NODE of the same name
                pos += 1;
              }
              tempitem2 = tempitem2.previousSibling;
            }
            if (el.namespaceURI != xml.documentElement.namespaceURI) {
              xpath = "*[local-name()='"+el.nodeName+"' and namespace-uri()='"+(el.namespaceURI===null?'':el.namespaceURI)+"']["+pos+']'+'/'+xpath;
            } else {
              xpath = el.nodeName.toUpperCase()+"["+pos+"]/"+xpath;
            }
            el = el.parentNode;
          }
          xpath = '/'+xml.documentElement.nodeName.toUpperCase()+'/'+xpath;
          xpath = xpath.replace(/\\/$/, '');
          return xpath;
        }
        JAVASCRIPT
      end

      def trigger(event)
        Trigger.new(@element, event).execute
      end

      class Trigger
        # https://github.com/microsoft/playwright/blob/837ee08a53f205325825874bbed8b30e3eb02dd5/src/server/injected/injectedScript.ts#L705
        EVENT_TYPES = [
          ['auxclick', 'mouse'],
          ['click', 'mouse'],
          ['dblclick', 'mouse'],
          ['mousedown','mouse'],
          ['mouseeenter', 'mouse'],
          ['mouseleave', 'mouse'],
          ['mousemove', 'mouse'],
          ['mouseout', 'mouse'],
          ['mouseover', 'mouse'],
          ['mouseup', 'mouse'],
          ['mouseleave', 'mouse'],
          ['mousewheel', 'mouse'],

          ['keydown', 'keyboard'],
          ['keyup', 'keyboard'],
          ['keypress', 'keyboard'],
          ['textInput', 'keyboard'],

          ['touchstart', 'touch'],
          ['touchmove', 'touch'],
          ['touchend', 'touch'],
          ['touchcancel', 'touch'],

          ['pointerover', 'pointer'],
          ['pointerout', 'pointer'],
          ['pointerenter', 'pointer'],
          ['pointerleave', 'pointer'],
          ['pointerdown', 'pointer'],
          ['pointerup', 'pointer'],
          ['pointermove', 'pointer'],
          ['pointercancel', 'pointer'],
          ['gotpointercapture', 'pointer'],
          ['lostpointercapture', 'pointer'],

          ['focus', 'focus'],
          ['blur', 'focus'],

          ['drag', 'drag'],
          ['dragstart', 'drag'],
          ['dragend', 'drag'],
          ['dragover', 'drag'],
          ['dragenter', 'drag'],
          ['dragleave', 'drag'],
          ['dragexit', 'drag'],
          ['drop', 'drag'],
        ].to_h

        def initialize(element, event)
          # https://github.com/microsoft/playwright/blob/837ee08a53f205325825874bbed8b30e3eb02dd5/src/server/injected/injectedScript.ts#L629
          @element = element
          @event_type = event
          @event = EVENT_TYPES[event.to_s]
          raise ArgumentError.new("Unknown event type: '#{event}'") unless @event
        end

        def execute
          js = <<~JAVASCRIPT
          (el, eventType) => {
            const eventInit = { bubbles: true, cancelable: true, composed: true };
            const event = new #{event_class}(eventType, eventInit);
            el.dispatchEvent(event);
          }
          JAVASCRIPT

          @element.evaluate(js, @event_type)
        end

        private def event_class
          case @event
          when 'mouse'
            :MouseEvent
          when 'keyboard'
            :KeyboardEvent
          when 'touch'
            :TouchEvent
          when 'pointer'
            :PointerEvent
          when 'focus'
            :FocusEvent
          when 'drag'
            :DragEvent
          else
            :Event
          end
        end
      end

      def inspect
        %(#<#{self.class} tag="#{tag_name}" path="#{path}">)
      end

      def ==(other)
        return false unless other.is_a?(Node)

        @element.evaluate('(self, other) => self == other', other.native)
      end

      def find_xpath(query, **options)
        @element.Sx(query).map do |el|
          Node.new(@driver, @page, el)
        end
      end

      def find_css(query, **options)
        @element.query_selector_all(query).map do |el|
          Node.new(@driver, @page, el)
        end
      end

      private def capybara_default_wait_time
        Capybara.default_max_wait_time * 1000
      end
    end
  end
end
