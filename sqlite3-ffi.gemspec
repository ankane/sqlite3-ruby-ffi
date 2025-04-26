require_relative "lib/sqlite3/ffi/version"

Gem::Specification.new do |spec|
  spec.name          = "sqlite3-ffi"
  spec.version       = SQLite3::FFI::VERSION
  spec.summary       = "A drop-in replacement for sqlite3 for JRuby"
  spec.homepage      = "https://github.com/ankane/sqlite3-ffi"
  spec.license       = "BSD-3-Clause"

  spec.authors       = ["Jamis Buck", "Luis Lavena", "Aaron Patterson", "Mike Dalessio", "Andrew Kane"]
  spec.email         = "andrew@ankane.org"

  spec.files         = Dir["*.{md,txt}", "{lib}/**/*"]
  spec.require_path  = "lib"

  spec.required_ruby_version = ">= 3.1"

  spec.add_dependency "ffi"
end
