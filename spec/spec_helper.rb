require 'simplecov'
require 'simplecov-lcov'
require 'coveralls' if ENV['TRAVIS']

SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
formatters = []
formatters << SimpleCov::Formatter::LcovFormatter
formatters << Coveralls::SimpleCov::Formatter if ENV['TRAVIS']
SimpleCov.formatters = formatters
SimpleCov.start do
  add_filter(/^\/spec\//)
end

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rspec'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  config.after do
    $stdout = StringIO.new
    PutsDebuggerer.printer = :puts
    PutsDebuggerer.print_engine = :p
    PutsDebuggerer.formatter = nil
    PutsDebuggerer.header = nil
    PutsDebuggerer.footer = nil
    PutsDebuggerer.wrapper = nil
    PutsDebuggerer.caller = nil
    PutsDebuggerer.app_path = nil  
    PutsDebuggerer.run_at = nil
    PutsDebuggerer::RunDeterminer.run_at_global_number = nil
    PutsDebuggerer::RunDeterminer::OBJECT_RUN_AT.clear
  end
end

require 'awesome_print'
require 'pd' # tests both `require 'pd'` and `require 'puts_debuggerer'`
