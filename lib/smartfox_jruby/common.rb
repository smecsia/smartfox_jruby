require 'java'
require 'active_support/all'
java_import com.smartfoxserver.v2.entities.data.ISFSObject
java_import com.smartfoxserver.v2.entities.data.SFSObject
java_import com.smartfoxserver.v2.entities.data.SFSArray
java_import java.util.Arrays
java_import 'sfs2x.client.core.IEventListener'
java_import 'sfs2x.client.core.SFSEvent'
java_import 'sfs2x.client.SmartFox'
java_import 'sfs2x.client.requests.LoginRequest'
java_import 'sfs2x.client.requests.ExtensionRequest'

module ISFSObject
  def to_hash
    HashWithIndifferentAccess.new(JSON.parse(to_json))
  end

  def to_s
    to_json
  end
end

module SmartfoxJruby
  module SFSUtil
    class << self
      def boxing(v, type)
        case type
          when :long
            java.lang.Long.valueOf(v)
          when :float
            java.lang.Float.valueOf(v)
          when :double
            java.lang.Double.valueOf(v)
          when :int
            java.lang.Integer.valueOf(v)
          when :boolean
            java.lang.Boolean.valueOf(v)
          else
            v
        end
      end

      def to_java_list(value, type)
        list = java.util.ArrayList.new
        value.to_java(type).each do |v|
          list.add(boxing(v, type))
        end
        list
      end
    end
  end
end


def SFSObject.from_hash(hash, opts = {})
  res = SFSObject.new
  opts ||= {}
  hash.each_key do |key|
    value = hash[key]
    key = key.to_s
    type = opts["#{key}_type".to_sym]
    if value.is_a?(Hash)
      res.putSFSObject(key, from_hash(value, opts[key.to_sym]))
    elsif value.is_a?(Float)
      if type == :double
        res.putDouble(key, value.to_java(:double))
      else
        res.putFloat(key, value.to_java(:float))
      end
    elsif value.is_a?(Integer)
      if type == :long
        res.putLong(key, value.to_java(:long))
      else
        res.putInt(key, value.to_java(:int))
      end
    elsif value.is_a?(TrueClass) or value.is_a?(FalseClass)
      res.putBool(key, value.to_java(:boolean))
    elsif value.is_a?(String) or value.is_a?(Symbol)
      res.putUtfString(key, value.to_java(:string))
    elsif value.is_a?(Array)
      unless value.empty?
        if value[0].is_a?(Hash)
          array = SFSArray.new
          value.each { |hash|
            array.addSFSObject(from_hash(hash, opts[key.to_sym]))
          }
          res.putSFSArray(key, array)
        elsif value[0].is_a?(Float)
          if type == :double
            res.putDoubleArray(key, SmartfoxJruby::SFSUtil.to_java_list(value, :double))
          else
            res.putFloatArray(key, SmartfoxJruby::SFSUtil.to_java_list(value, :float))
          end
        elsif value[0].is_a?(Integer)
          if type == :long
            res.putLongArray(key, SmartfoxJruby::SFSUtil.to_java_list(value, :long))
          else
            res.putIntArray(key, SmartfoxJruby::SFSUtil.to_java_list(value, :int))
          end
        elsif value[0].is_a?(TrueClass) or value[0].is_a?(FalseClass)
          res.putBoolArray(key, SmartfoxJruby::SFSUtil.to_java_list(value, :boolean))
        elsif value[0].is_a?(String) or value[0].is_a?(Symbol)
          res.putUtfStringArray(key, SmartfoxJruby::SFSUtil.to_java_list(value, :string))
        end
      end
    end
  end
  res
end

class Hash
  include ISFSObject

  def to_sfsobject(opts = {})
    SFSObject.from_hash(self, opts)
  end

  def method_missing(m, *args)
    sfs_object = SFSObject.from_hash(self)
    if sfs_object.respond_to?(m)
      sfs_object.send(m, *args)
    else
      super
    end
  end
end

module Kernel
  class WaitTimeoutException < Exception
  end

  def wait_with_timeout(timeout = 20, opts = {:sleep_time => 0.1})
    timeout ||= 20
    raise "Block is required!" unless block_given?
    time = Time.now.to_i
    finished = false
    while (Time.now.to_i < time + timeout) && !finished
      sleep opts[:sleep_time] || 0.01 # sleep for 10 ms to wait the response
      finished = yield
    end
    raise WaitTimeoutException.new("Timeout while waiting!") unless finished
  end
end

module Process
  def self.alive?(pid)
    return false unless pid
    begin
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    end
  end
end