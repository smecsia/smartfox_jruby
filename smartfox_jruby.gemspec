require 'pathname'

require Pathname.new(File.dirname(File.expand_path(__FILE__))).join('lib/smartfox_jruby.rb')

Gem::Specification.new do |s|
  s.name = 'smartfox_jruby'
  s.version = SmartfoxJruby::VERSION
  s.date = '2013-03-02'
  s.authors = ["Ilya Sadykov"]
  s.email = 'smecsia@gmail.com'
  s.homepage = "https://github.com/smecsia/smartfox_jruby"
  s.summary = %q{This lib allows to test Smartfox server extensions in an easy manner}
  s.description = %q{Allows to connect and easily process messages from and to SmartFox game server}

  s.add_development_dependency 'rspec', '~> 2.10.0'
  s.add_dependency 'json'
  s.add_dependency 'activesupport', '~> 3.2.8'

  s.require_path = 'lib'
  s.files = Dir['{lib,spec}/**/*','README*']
end