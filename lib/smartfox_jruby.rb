require 'rubygems'
require 'ostruct'
require 'pathname'

####################################################
# Main module
module SmartfoxJruby
  MYDIR = Pathname.new(File.dirname(File.expand_path(__FILE__)))
  autoload :SfsRunner, MYDIR.join('smartfox_jruby/sfs_runner')
  autoload :SfsAdapter, MYDIR.join('smartfox_jruby/sfs_adapter')
  autoload :SfsWorker, MYDIR.join('smartfox_jruby/sfs_worker')
  autoload :SFSUtil, MYDIR.join('smartfox_jruby/common')
  VERSION = "0.2.4"
end

