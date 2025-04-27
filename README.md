# sqlite3-ruby-ffi

:tada: A drop-in replacement for [sqlite3](https://github.com/sparklemotion/sqlite3-ruby) for JRuby

- Passes > 99% of the sqlite3 test suite
- Works with Active Record without a custom adapter

[![Build Status](https://github.com/ankane/sqlite3-ruby-ffi/actions/workflows/build.yml/badge.svg)](https://github.com/ankane/sqlite3-ruby-ffi/actions)

## Installation

Add this line to your Gemfile:

```ruby
gem "sqlite3-ffi"
```

And use it the same way as the sqlite3 gem.

## Why FFI for JRuby?

I tried [JDBC](https://github.com/xerial/sqlite-jdbc), [JNI](https://sqlite.org/src/dir/ext/jni), and FFI. Since SQLite is written in C, all three approaches eventually call C, and FFI provides the most compatibility.

## Credits

This library uses code from the [sqlite3](https://github.com/sparklemotion/sqlite3-ruby) gem and is available under the same license.

The code in `lib` and `test` is an exact copy, plus some additional files:

- `lib/sqlite3/ffi/*` (port of `ext`)
- `lib/sqlite3/ffi.rb`
- `lib/sqlite3/sqlite3_native.rb`
- `test/ffi_helper.rb`

## History

View the [changelog](https://github.com/ankane/sqlite3-ruby-ffi/blob/master/CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/sqlite3-ruby-ffi/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/sqlite3-ruby-ffi/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started with development:

```sh
git clone https://github.com/ankane/sqlite3-ruby-ffi.git
cd sqlite3-ruby-ffi
bundle install
bundle exec rake test
```
