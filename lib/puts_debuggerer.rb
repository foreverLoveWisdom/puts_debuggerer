$LOAD_PATH.unshift(File.expand_path(__dir__)) unless $LOAD_PATH.include?(File.expand_path(__dir__))

require 'puts_debuggerer/core_ext/kernel'
require 'puts_debuggerer/core_ext/logger'
require 'puts_debuggerer/core_ext/logging/logger'
require 'puts_debuggerer/run_determiner'
require 'puts_debuggerer/source_file'

module PutsDebuggerer
  SOURCE_LINE_COUNT_DEFAULT = 1
  HEADER_DEFAULT = '>'*80
  WRAPPER_DEFAULT = '*'*80
  FOOTER_DEFAULT = '<'*80
  LOGGER_FORMATTER_DECORATOR = proc { |original_formatter|
    proc { |severity, datetime, progname, msg|
      original_formatter.call(severity, datetime, progname, msg.pd_inspect)
    }
  }
  LOGGING_LAYOUT_DECORATOR = proc {|original_layout|
    original_layout.clone.tap do |layout|
      layout.singleton_class.class_eval do
        alias original_format_obj format_obj
        def format_obj(obj)
          obj.pdi # alias to pd_inspect
        end
      end
    end
  }
  RETURN_DEFAULT = true
  OBJECT_PRINTER_DEFAULT = lambda do |object, print_engine_options=nil, source_line_count=nil, run_number=nil|
    lambda do
      if object.is_a?(Exception)
        if RUBY_ENGINE == 'opal'
          object.backtrace.each { |line| puts line }
        else
          puts object.full_message
        end
      elsif PutsDebuggerer.print_engine.is_a?(Proc)
        PutsDebuggerer.print_engine.call(object)
      else
        send(PutsDebuggerer.print_engine, object)
      end
    end
  end
  PRINTER_DEFAULT = :puts
  PRINTER_RAILS = lambda do |output|
    puts output if Rails.env.test?
    Rails.logger.debug(output)
  end
  PRINT_ENGINE_DEFAULT = :ap
  PRINTER_MESSAGE_INVALID = 'printer must be a valid global method symbol (e.g. :puts), a logger, or a lambda/proc receiving a text arg'
  PRINT_ENGINE_MESSAGE_INVALID = 'print_engine must be a valid global method symbol (e.g. :p, :ap or :pp) or lambda/proc receiving an object arg'
  ANNOUNCER_DEFAULT = '[PD]'
  FORMATTER_DEFAULT = -> (data) {
      puts data[:wrapper] if data[:wrapper]
      puts data[:header] if data[:header]
      print "#{data[:announcer]} #{data[:file]}#{':' if data[:line_number]}#{data[:line_number]} in #{[data[:class], data[:method]].compact.join('.')}#{" (run:#{data[:run_number]})" if data[:run_number]}#{__format_pd_expression__(data[:pd_expression], data[:object])} "
      data[:object_printer].call
      puts data[:caller].map {|l| '     ' + l} unless data[:caller].to_a.empty?
      puts data[:footer] if data[:footer]
      puts data[:wrapper] if data[:wrapper]
    }
  CALLER_DEPTH_ZERO = 4 #depth includes pd + with_options method + nested block + build_pd_data method
  CALLER_DEPTH_ZERO_OPAL = -1 #depth includes pd + with_options method + nested block + build_pd_data method
  STACK_TRACE_CALL_LINE_NUMBER_REGEX = /\:(\d+)\:in /
  STACK_TRACE_CALL_SOURCE_FILE_REGEX = /[ ]*([^:]+)\:\d+\:in /
  STACK_TRACE_CALL_SOURCE_FILE_REGEX_OPAL = /(http[^\)]+)/
  STACK_TRACE_CALL_METHOD_REGEX = /`([^']+)'$/
  OPTIONS = [:app_path, :source_line_count, :header, :h, :wrapper, :w, :footer, :f, :printer, :print_engine, :announcer, :formatter, :caller, :run_at]
  OPTION_ALIASES = {
    a: :announcer,
    c: :caller,
    h: :header,
    f: :footer,
    w: :wrapper,
  }

  class << self
    # Application root path to exclude when printing out file path
    #
    # Example:
    #
    #   # File Name: /Users/User/sample_app/lib/sample.rb
    #   PutsDebuggerer.app_path = '/Users/User/sample_app'
    #   pd (x=1)
    #
    # Prints out:
    #
    #   [PD] lib/sample.rb:3
    #      > pd x=1
    #     => "1"
    attr_reader :app_path

    def app_path=(path)
      @app_path = (path || Rails.root.to_s) rescue nil
    end

    # Source Line Count.
    # * Default value is `1`
    #
    # Example:
    #
    #   PutsDebuggerer.source_line_count = 2
    #   pd (true ||
    #     false), source_line_count: 2
    #
    # Prints out:
    #
    #   ********************************************************************************
    #   [PD] /Users/User/example.rb:2
    #      > pd (true ||
    #          false), source_line_count: 2
    #     => "true"
    attr_reader :source_line_count

    def source_line_count=(value)
      @source_line_count = value || SOURCE_LINE_COUNT_DEFAULT
    end

    # Header to include at the top of every print out.
    # * Default value is `nil`
    # * Value `true` enables header as `'*'*80`
    # * Value `false`, `nil`, or empty string disables header
    # * Any other string value gets set as a custom header
    #
    # Example:
    #
    #   PutsDebuggerer.header = true
    #   pd (x=1)
    #
    # Prints out:
    #
    #   ********************************************************************************
    #   [PD] /Users/User/example.rb:2
    #      > pd x=1
    #     => "1"
    attr_reader :header

    # Wrapper to include at the top and bottom of every print out (both header and footer).
    # * Default value is `nil`
    # * Value `true` enables wrapper as `'*'*80`
    # * Value `false`, `nil`, or empty string disables wrapper
    # * Any other string value gets set as a custom wrapper
    #
    # Example:
    #
    #   PutsDebuggerer.wrapper = true
    #   pd (x=1)
    #
    # Prints out:
    #
    #   [PD] /Users/User/example.rb:2
    #      > pd x=1
    #     => "1"
    #   ********************************************************************************
    attr_reader :wrapper

    # Footer to include at the bottom of every print out.
    # * Default value is `nil`
    # * Value `true` enables footer as `'*'*80`
    # * Value `false`, `nil`, or empty string disables footer
    # * Any other string value gets set as a custom footer
    #
    # Example:
    #
    #   PutsDebuggerer.footer = true
    #   pd (x=1)
    #
    # Prints out:
    #
    #   [PD] /Users/User/example.rb:2
    #      > pd x=1
    #     => "1"
    #   ********************************************************************************
    attr_reader :footer
    
    ['header', 'footer', 'wrapper'].each do |boundary_option|
      define_method("#{boundary_option}=") do |value|
        if value.equal?(true)
          instance_variable_set(:"@#{boundary_option}", const_get(:"#{boundary_option.upcase}_DEFAULT"))
        elsif value == ''
          instance_variable_set(:"@#{boundary_option}", nil)
        else
          instance_variable_set(:"@#{boundary_option}", value)
        end
      end
      
      define_method("#{boundary_option}?") do
        !!instance_variable_get(:"@#{boundary_option}")
      end
    end

    # Printer is a global method symbol, lambda expression, or logger to use in printing to the user.
    # Examples of a global method are `:puts` and `:print`.
    # An example of a lambda expression is `lambda {|output| Rails.logger.ap(output)}`
    # Examples of a logger are a Ruby `Logger` instance or `Logging::Logger` instance
    #
    # Defaults to `:puts`
    # In Rails, it defaults to: `lambda {|output| Rails.logger.ap(output)}`
    #
    # Example:
    #
    # # File Name: /Users/User/example.rb
    # PutsDebuggerer.printer = lambda {|output| Rails.logger.error(output)}
    # str = "Hello"
    # pd str
    #
    # Prints out in the Rails app log as error lines:
    #
    # [PD] /Users/User/example.rb:5
    #    > pd str
    #   => Hello
    attr_reader :printer

    def printer=(printer)
      if printer.nil?
        @printer = printer_default
      elsif printer.is_a?(Logger)
        @printer = printer
        @logger_original_formatter = printer.formatter || Logger::Formatter.new
        printer.formatter = LOGGER_FORMATTER_DECORATOR.call(@logger_original_formatter)
      elsif printer.is_a?(Logging::Logger)
        @printer = printer
        @logging_original_layouts = printer.appenders.reduce({}) do |hash, appender|
          hash.merge(appender => appender.layout)
        end
        printer.appenders.each do |appender|
          appender.layout = LOGGING_LAYOUT_DECORATOR.call(appender.layout)
        end
      elsif printer == false || printer.is_a?(Proc) || printer.respond_to?(:log) # a logger
        @printer = printer
      else
        @printer = method(printer).name rescue raise(PRINTER_MESSAGE_INVALID)
      end
    end
    
    def printer_default
      Object.const_defined?(:Rails) ? PRINTER_RAILS : PRINTER_DEFAULT
    end
    
    # Logger original formatter before it was decorated with PutsDebuggerer::LOGGER_FORMATTER_DECORATOR
    # upon setting the logger as a printer.
    attr_reader :logger_original_formatter
    
    # Logging library original layouts before being decorated with PutsDebuggerer::LOGGING_LAYOUT_DECORATOR
    # upon setting the Logging library logger as a printer.
    attr_reader :logging_original_layouts

    # Print engine is similar to `printer`, except it is focused on the scope of formatting
    # the data object being printed (excluding metadata such as file name, line number,
    # and expression, which are handled by the `printer`).
    # As such, it is also a global method symbol or lambda expression.
    # Examples of global methods are `:p`, `:ap`, and `:pp`.
    # An example of a lambda expression is `lambda {|object| puts object.to_a.join(" | ")}`
    #
    # Defaults to [awesome_print](https://github.com/awesome-print/awesome_print).
    #
    # Example:
    #
    #   # File Name: /Users/User/example.rb
    #   require 'awesome_print'
    #   PutsDebuggerer.print_engine = :p
    #   array = [1, [2, 3]]
    #   pd array
    #
    # Prints out:
    #
    #   [PD] /Users/User/example.rb:5
    #      > pd array
    #     => [1, [2, 3]]
    #   ]
    def print_engine
      if @print_engine.nil?
        require 'awesome_print' if RUBY_ENGINE != 'opal'
        @print_engine = print_engine_default
      end
      @print_engine
    end

    def print_engine=(engine)
      if engine.is_a?(Proc) || engine.nil?
        @print_engine = engine
      else
        @print_engine = method(engine).name rescue raise(PRINT_ENGINE_MESSAGE_INVALID)
      end
    end
    
    def print_engine_default
      Object.const_defined?(:AwesomePrint) ? PRINT_ENGINE_DEFAULT : :p
    end

    # Announcer (e.g. [PD]) to announce every print out with (default: "[PD]")
    #
    # Example:
    #
    #   PutsDebuggerer.announcer = "*** PD ***\n  "
    #   pd (x=1)
    #
    # Prints out:
    #
    #   *** PD ***
    #      /Users/User/example.rb:2
    #      > pd x=1
    #     => 1
    attr_reader :announcer

    def announcer=(text)
      @announcer = text.nil? ? ANNOUNCER_DEFAULT : text
    end

    # Formatter used in every print out
    # Passed a data argument with the following keys:
    # * :announcer (string)
    # * :caller (array)
    # * :file (string)
    # * :wrapper (string)
    # * :footer (string)
    # * :header (string)
    # * :line_number (string)
    # * :pd_expression (string)
    # * :object (object)
    # * :object_printer (proc)
    # * :source_line_count (integer)
    #
    # NOTE: data for :object_printer is not a string, yet a proc that must
    # be called to output value. It is a proc as it automatically handles usage
    # of print_engine and encapsulates its details. In any case, data for :object
    # is available should one want to avoid altogether.
    #
    # Example:
    #
    #   PutsDebuggerer.formatter = -> (data) {
    #     puts "-<#{data[:announcer]}>-"
    #     puts "HEADER: #{data[:header]}"
    #     puts "FILE: #{data[:file]}"
    #     puts "LINE: #{data[:line_number]}"
    #     puts "EXPRESSION: #{data[:pd_expression]}"
    #     print "PRINT OUT: "
    #     data[:object_printer].call
    #     puts "CALLER: #{data[:caller].to_a.first}"
    #     puts "FOOTER: #{data[:footer]}"
    #   }
    #   pd (x=1)
    #
    # Prints out:
    #
    #   -<[PD]>-
    #   FILE: /Users/User/example.rb
    #   HEADER: ********************************************************************************
    #   LINE: 9
    #   EXPRESSION: x=1
    #   PRINT OUT: 1
    #   CALLER: #/Users/User/master_examples.rb:83:in `block (3 levels) in <top (required)>'
    #   FOOTER: ********************************************************************************
    attr_reader :formatter

    def formatter=(formatter_proc)
      @formatter = formatter_proc.nil? ? FORMATTER_DEFAULT : formatter_proc
    end

    # Caller backtrace included at the end of every print out
    # Passed an argument of true/false, nil, or depth as an integer.
    # * true and -1 means include full caller backtrace
    # * false and nil means do not include caller backtrace
    # * depth (0-based) means include limited caller backtrace depth
    #
    # Example:
    #
    #   # File Name: /Users/User/sample_app/lib/sample.rb
    #   PutsDebuggerer.caller = 3
    #   pd (x=1)
    #
    # Prints out:
    #
    #   [PD] /Users/User/sample_app/lib/sample.rb:3
    #      > pd x=1
    #     => "1"
    #        /Users/User/sample_app/lib/master_samples.rb:368:in `block (3 levels) in <top (required)>'
    #        /Users/User/.rvm/rubies/ruby-2.4.0/lib/ruby/2.4.0/irb/workspace.rb:87:in `eval'
    #        /Users/User/.rvm/rubies/ruby-2.4.0/lib/ruby/2.4.0/irb/workspace.rb:87:in `evaluate'
    #        /Users/User/.rvm/rubies/ruby-2.4.0/lib/ruby/2.4.0/irb/context.rb:381:in `evaluate'
    attr_reader :caller

    def caller=(value)
      if value.equal?(true)
        @caller = -1 #needed for upper bound in pd method
      else
        @caller = value
      end
    end

    def caller?
      !!caller
    end


    # Options as a hash. Useful for reading and backing up options
    def options
      {
        header: header,
        wrapper: wrapper,
        footer: footer,
        printer: printer,
        print_engine: print_engine,
        source_line_count: source_line_count,
        app_path: app_path,
        announcer: announcer,
        formatter: formatter,
        caller: caller,
        run_at: run_at
      }
    end

    # Sets options included in hash
    def options=(hash)
      hash.each do |option, value|
        send("#{option}=", value)
      end
    end

    # When to run as specified by an index, array, or range.
    # * Default value is `nil` meaning always
    # * Value as an Integer index (1-based) specifies at which run to print once
    # * Value as an Array of indices specifies at which runs to print multiple times
    # * Value as a range specifies at which runs to print multiple times,
    #   indefinitely if it ends with ..-1
    #
    # Example:
    #
    #   PutsDebuggerer.run_at = 1
    #   pd (x=1) # prints standard PD output
    #   pd (x=1) # prints nothing
    #
    #   PutsDebuggerer.run_at = 2
    #   pd (x=1) # prints nothing
    #   pd (x=1) # prints standard PD output
    #
    #   PutsDebuggerer.run_at = [1, 3]
    #   pd (x=1) # prints standard PD output
    #   pd (x=1) # prints nothing
    #   pd (x=1) # prints standard PD output
    #   pd (x=1) # prints nothing
    #
    #   PutsDebuggerer.run_at = 3..5
    #   pd (x=1) # prints nothing
    #   pd (x=1) # prints nothing
    #   pd (x=1) # prints standard PD output
    #   pd (x=1) # prints standard PD output
    #   pd (x=1) # prints standard PD output
    #   pd (x=1) # prints nothing
    #   pd (x=1) # prints nothing
    #
    #   PutsDebuggerer.run_at = 3...6
    #   pd (x=1) # prints nothing
    #   pd (x=1) # prints nothing
    #   pd (x=1) # prints standard PD output
    #   pd (x=1) # prints standard PD output
    #   pd (x=1) # prints standard PD output
    #   pd (x=1) # prints nothing
    #
    #   PutsDebuggerer.run_at = 3..-1
    #   pd (x=1) # prints nothing
    #   pd (x=1) # prints nothing
    #   pd (x=1) # prints standard PD output
    #   pd (x=1) ... continue printing indefinitely on all subsequent runs
    #
    #   PutsDebuggerer.run_at = 3...-1
    #   pd (x=1) # prints nothing
    #   pd (x=1) # prints nothing
    #   pd (x=1) # prints standard PD output
    #   pd (x=1) ... continue printing indefinitely on all subsequent runs
    attr_reader :run_at

    def run_at=(value)
      @run_at = value
    end

    def run_at?
      !!@run_at
    end

    def determine_options(objects)
      if objects.size > 1 && objects.last.is_a?(Hash)
        convert_options(objects.delete_at(-1))
      elsif objects.size == 1 && objects.first.is_a?(Hash)
        hash = objects.first
        convert_options(hash.slice(*OPTIONS).tap do
          hash.delete_if {|option| OPTIONS.include?(option)}
        end)
      end
    end
    
    def convert_options(hash)
      Hash[hash.map { |key, value| OPTION_ALIASES[key] ? ( value == :t ?  [OPTION_ALIASES[key], true] : [OPTION_ALIASES[key], value] ) : [key, value]}]
    end

    def determine_object(objects)
      objects.compact.size > 1 ? objects : objects.first
    end

    def determine_run_at(options)
      ((options && options[:run_at]) || PutsDebuggerer.run_at)
    end

    def determine_printer(options)
      if options && options.has_key?(:printer)
        options[:printer]
      else
        PutsDebuggerer.printer
      end
    end
  end
end

# setting values to nil defaults them properly
PutsDebuggerer.printer = nil
PutsDebuggerer.print_engine = nil
PutsDebuggerer.announcer = nil
PutsDebuggerer.formatter = nil
PutsDebuggerer.app_path = nil
PutsDebuggerer.caller = nil
PutsDebuggerer.run_at = nil
PutsDebuggerer.source_line_count = nil
