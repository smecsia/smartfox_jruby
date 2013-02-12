require File.expand_path(File.dirname(__FILE__) + '/sfs_worker')

module SmartfoxJruby

  class SfsAdapter
    include IEventListener
    attr_reader :opts
    attr_reader :smart_fox
    attr_reader :worker
    attr_reader :username
    DEBUG = false

    def initialize(opts = {})
      @opts = opts
      @smart_fox = SmartFox.new(false)
      @connected = false
      @worker = opts[:worker]
      @login_as = opts[:login_as] || {}
      @opts[:timeout] ||= 20
      @opts[:logger] ||= Logger.new(STDOUT)
      SFSEvent.constants.each do |evt|
        evt_value = SFSEvent.const_get(evt)
        debug "Registering event adapter to self for event '#{evt}' --> '#{evt_value}'..."
        smart_fox.add_event_listener(evt_value, self)
      end
      debug "initializing sfs adapter..."
    end

    def connect!(opt = {})
      opts.reverse_merge!(opt)
      raise "host and port are required to connect SfsAdapter!" if opts[:host].blank? || opts[:port].blank?
      debug "connecting to smartfox at #{opts[:host]}:#{opts[:port]} ..."
      smart_fox.connect(opts[:host], opts[:port])
    end

    def dispatch(event)
      debug "got event #{event.type}: #{event}"
      callback = "on_#{event.type.try(:underscore)}_event"
      if respond_to?(callback, true)
        send(callback, event)
      else
        debug "Unknown event caught #{event.type} (No method '#{callback}' in #{self})"
      end
    end

    def disconnect!
      smart_fox.disconnect
    end

    def process!(wrk = nil, &block)
      wait_with_timeout(@opts[:timeout]) { connected? }
      @worker = wrk || opts[:worker]
      if block_given? && connected?
        instance_eval(&block)
      else
        raise "Worker is null!" if @worker.blank?
        raise "Not connected!" unless connected?
      end
      worker.perform!
    end

    def connected?
      @connected
    end

    def on_connect(&block)
      @on_connect ||= []
      @on_connect << block if block_given?
    end

    def on_login(&block)
      @on_login ||= []
      @on_login << block if block_given?
    end

    def login_as(username, password, params = {})
      params = params.to_sfsobject if params.is_a?(Hash)
      @login_as = {:username => username, :password => password, :params => params}
    end

    private

    ###############
    ### HELPERS ###

    def request(*args)
      worker.request(*args)
    end

    def worker(opts = {})
      @worker ||= SfsWorker::Worker.new(@smart_fox, opts)
      @worker
    end

    def sfs_send(req)
      smart_fox.send(req)
    end

    #########################
    ### EVENTS PROCESSORS ###

    def on_extension_response_event(event)
      debug "extension_response #{event.arguments.get("cmd")}"
      @worker.response(event.arguments.get("cmd"), event.arguments.get("params").try(:to_hash) || {}) unless @worker.blank?
    end

    def on_connection_event(event)
      debug "on_connection #{event}"
      @on_connect.each { |block|
        block.call(event) if block.is_a?(Proc)
      } unless @on_connect.blank?
      sfs_send(LoginRequest.new(@login_as[:username], @login_as[:password], opts[:zone],
                                (@login_as[:params] || {}.to_sfsobject)));
    end

    def on_login_event(event)
      args = event.arguments.get("data").to_hash
      user = event.arguments.get("user")
      debug("on_login, args=#{args.to_json}")
      unless user.blank?
        info "connected as #{user.name}"
        @username = user.name
        @connected = true
        @on_login.each { |block|
          block.call(@username) if block.is_a?(Proc)
        } unless @on_login.blank?
      else
        raise "login error '#{args[Aimy::Param.ERROR_MESSAGE]}'"
      end
    end

    def on_login_error_event(event)
      error("error while logging-in: #{event.arguments}")
    end

    def on_connection_lost_event(event)
      # nothing to do
    end

    def on_handshake_event(event)
      # nothing to do
    end


    #######################
    ### SERVICE HELPERS ###

    def logger
      opts[:logger]
    end

    def debug_enabled?
      opts[:debug] || DEBUG
    end

    def debug(msg)
      logger.debug "#{msg}" if debug_enabled?
    end

    def info(msg)
      logger.info "#{msg}"
    end

    def log(msg)
      logger.info "#{msg}"
    end

    def error(msg)
      logger.error "#{msg}"
    end

  end

end
