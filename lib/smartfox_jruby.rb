require 'rubygems'
require 'ostruct'
require 'pathname'

####################################################
# Main module
module SmartfoxJruby
  autoload :SfsRunner, 'smartfox_jruby/sfs_runner'
  autoload :SfsAdapter, 'smartfox_jruby/sfs_adapter'
  autoload :SfsWorker, 'smartfox_jruby/sfs_worker'
  autoload :SFSUtil, 'smartfox_jruby/common'
  VERSION = "0.2.2"

end

