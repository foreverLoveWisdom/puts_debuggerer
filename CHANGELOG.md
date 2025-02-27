# Change Log

## 1.0.0

-  Support including class/method after file/line in every `pd` printout

## 0.13.5

- Fix not printing source line in Rails app w/ Pry
- Note that Pry's compatibility (inside Pry) is experimental and fragile because Pry's API is not reliable

## 0.13.4

- Reverted change to default `printer` behavior from 0.13.3 to avoid causing a double-print to stdout as it turns out `puts` is not always needed since Rails redirects to standard out by default in `Rails.logger.debug` calls

## 0.13.3

- Update default `printer` behavior for Rails to always output via `puts` (not just in tests) in addition to `Rails.logger.debug`
- Update custom implementation of `caller` for Opal to accept args (optional `start` and `length` or alternatively `range`) just like the Ruby API

## 0.13.2

- Fix issue caused by MiniTest Rails having `IRB` constant declared despite being outside of IRB

## 0.13.1

- Support `a: '[PD]'` shortcut to passing `announcer: '[PD]'`
- Support `c: :t` shortcut to passing `caller: true`

## 0.13.0

- Support `h: :t` shortcut to passing `header: true`
- Support `f: :t` shortcut to passing `footer: true`
- Support `w: :t` shortcut to passing `wrapper: true`

## 0.12.0

- Upgrade `awesome_print` to `~> 1.9.2`
- Support passing pd options as part of a printed hash instead of requiring a separate hash (e.g. `pd(path: path, header: true)` instead of `pd({path: path}, header: true)` )
- Support empty use of pd statement + options (e.g. `pd` or `pd header: true`)

## 0.11.0

- Pry support
- In Opal, print exceptions as errors in the web console using an alternative to full_message since it's not implemented in Opal yet
- Fix `pd_inspect` and `pdi` in IRB

## 0.10.2

- Improve Opal Ruby compatibility by displaying source file/line

## 0.10.1

- Remove the need for specifying `require 'ap'` before `require 'pd'`

## 0.10.0

- Support `require 'pd`' as a shorter alternative to `require 'puts_debuggerer'`
- Support `printer` as a Logger object or Logging::Logger (from "logging" gem). Basically any object that responds to :debug method.
- Support `printer: false` option to return rendered String instead of printing and returning object
- Set logger formatter to PutsDebuggerer::LOGGER_FORMATTER_DECORATOR when passing as printer (keeping format the same, but decorating msg with pd)
- Add pd_inspect (and pdi alias) Kernel core extension methods
- Made awesome_print gem require happen only if printer is set to :ap or :awesome_print
- Support logging gem logger and Decorate logger layout with PutsDebuggerer::LOGGING_LAYOUT_DECORATOR for logging gem

## 0.9.0

- Provide partial support for Opal Ruby (missing display of file name, line number, and source code)
- `source_line_count` option
- `wraper` option for including both `header` and `footer`
- Special handling of exceptions (prints using full_message)
- Change :ap printer default to :p when unavailable
- Support varargs printing (example: `pd arg1, arg2, arg3`)
- Display `run_at` run number in printout

## 0.8.2

- require 'stringio' for projects that don't require automatically via other gems

## 0.8.1

- `printer` option support for Rails test environment

## 0.8.0

- `printer` option support

## 0.7.1

- default print engine to :ap (AwesomePrint)

## 0.7.0

- `run_at` option, global and piecemeal.

## 0.6.1

- updated README and broke apart specs

## 0.6.0

- unofficial erb support, returning evaluated object/expression, removed static syntax support (replaced with header support)

## 0.5.1

- support for print engine lambdas and smart defaults for leveraging Rails and AwesomePrint debuggers in Rails

## 0.5.0

- custom formatter, caller backtrace, per-puts piecemeal options, and multi-line support

## 0.4.0

- custom print engine (e.g. ap), custom announcer, and IRB support

## 0.3.0

- header/footer support, multi-line printout, improved format

## 0.2.0

- App path exclusion support, Rails root support, improved format

## 0.1.0

- File/line/expression print out
