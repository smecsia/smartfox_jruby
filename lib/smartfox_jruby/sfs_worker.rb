require 'thread'
require File.expand_path(File.dirname(__FILE__) + '/common')

module SmartfoxJruby
  module SfsWorker
    class Processor
      attr_accessor :opts
      attr_accessor :name
      attr_accessor :chained
      attr_accessor :current
      attr_accessor :blocks

      def initialize(name, opts = {}, &block)
        @blocks = [block]
        @name = name
        @current = self
        @chained = nil
        @opts = opts
      end

      def chain(name, &block)
        link.chained = Processor.new(name, @opts, &block)
        self
      end

      def link
        p = current
        p = p.chained while (!p.try(:chained).blank?)
        p
      end

      def append(&block)
        unless link.blank?
          link.blocks << block
        else
          current.blocks << block
        end
        self
      end

      def completed?
        current.blank?
      end

      def mandatory?
        @opts[:mandatory].nil? || @opts[:mandatory]
      end

      def event(name, data = {})
        if @current.name.to_s == name.to_s
          @current.blocks.each { |b| b.call(data) }
          @current = (@current.chained.blank?) ? nil : @current.chained
          return true
        end
        false
      end

      def to_s
        "Proc[#{current.try(:name)}] --> #{current.try(:chained)}"
      end
    end

    class Request
      attr_reader :name
      attr_reader :data

      def initialize(name, data = {})
        @name = name
        @data = data
      end

      def to_extension_request
        ExtensionRequest.new(@name.to_s, @data)
      end

      def to_s
        "Req[#{@name}]#{data.to_json}"
      end
    end

    class Response < Request
      def to_s
        "Resp[#{@name}]#{data.to_json}"
      end
    end

    class ContextWorker

      def request(name, data = {}, opts = {})
        @worker.request(name, data, opts.merge(:context => @context))
      end

      def append_processor(opts = {}, &block)
        @worker.append_processor(opts.merge(:context => @context), &block)
      end

      def expect(name, opts={}, &block)
        @worker.expect(name, opts.merge(:context => @context), &block)
      end

      def initialize(context, worker)
        @context = context
        @worker = worker
      end
    end

    class Worker
      attr_reader :send_queue
      attr_reader :events_queue
      attr_reader :processors
      attr_reader :smart_fox
      attr_reader :opts

      def initialize(smart_fox, opts = {})
        @send_queue = []
        @processors = []
        @events_queue = []
        @opts = opts
        @opts[:timeout] ||= 20
        @smart_fox = smart_fox
        @mutex = Mutex.new
        @send_qm = Mutex.new
      end

      def append_processor(opts = {}, &block)
        debug "appending processor with context #{opts[:context]}"
        if opts[:context]
          context = opts[:context].append(&block)
        else
          context = processors.last.append(&block)
        end
        ContextWorker.new(context, self)
      end

      def request(name, data = {}, opts = {})
        debug "create request #{name} with context #{opts[:context]} and opts #{opts[:serialize_opts]}"
        data = data.to_sfsobject(opts[:serialize_opts]) if data.is_a?(Hash)
        req = Request.new(name, data)
        if !opts[:context].blank? && opts[:context].is_a?(Processor)
          debug "appending #{req} to processor #{opts[:context]}"
          context = opts[:context].append {
            @send_qm.synchronize { send_queue << req }
          }
        else
          debug "adding #{req} to send_queue \n #{dump_state}"
          context = req
          @send_qm.synchronize { send_queue << req }
        end
        ContextWorker.new(context, self)
      end

      def expect(name, opts = {}, &block)
        debug "Expecting to get response #{name} with context #{opts[:context]}"
        unless opts[:context].blank?
          if opts[:context].is_a?(Processor)
            context = opts[:context].chain(name, &block)
          elsif opts[:context].is_a?(Request)
            context = Processor.new(name, :context => opts[:context], &block)
            @mutex.synchronize { processors << context }
          end
        else
          context = Processor.new(name, &block)
          @mutex.synchronize { processors << context }
        end
        ContextWorker.new(context, self)
      end

      def response(name, data = {})
        info "Got response #{name} (#{data.to_json})..."
        @mutex.synchronize { events_queue << Response.new(name, data) }
      end

      def perform!
        while !all_events_caught?
          while !send_queue.blank?
            req = nil
            @send_qm.synchronize { req = send_queue.shift }
            debug "sending request #{req.name}..."
            smart_fox.send(req.to_extension_request) unless smart_fox.blank?
            @last_act = Time.now.to_i
          end
          process_events
          check_timeouts
        end
      end

      def all_events_caught?
        processors.blank? || processors.collect { |p| p.mandatory? }.blank?
      end

      def wait_all_events_caught
        debug "Waiting all events being caught..."
        begin
          wait_with_timeout { all_events_caught? }
        rescue WaitTimeoutException => e
          raise "Failed to catch all the events:"+ dump_state
        end
      end

      private

      def dump_state
        "events_queue = \n\t-#{events_queue.join("\n\t-")}" +
            " \n processors = \n\t-#{processors.join("\n\t-")}" +
            " \n send_queue = \n\t-#{send_queue.join("\n\t-")}"
      end

      def check_timeouts
        if !@last_act.blank? && Time.now.to_i > @last_act + opts[:timeout]
          raise "Worker timeout! Latest interaction was #{Time.now.to_i - @last_act} sec ago!\n #{dump_state}"
        end
      end

      def process_events
        wait_with_timeout { !events_queue.blank? } rescue nil
        ei = 0
        debug "Processing events..."
        while ei < events_queue.size
          event = events_queue[ei]
          pi = 0
          debug "Processing event #{event.name}..."
          while pi < processors.size
            processor = processors[pi]
            debug "Trying processor #{processor.name}..."
            if processor.event(event.name, event.data)
              @last_act = Time.now.to_i
              debug "Processor found #{processor}"
              @mutex.synchronize { events_queue.delete_at(ei) }
              ei -= 1
              if processor.completed?
                debug "Processor completed #{processor.name}."
                @mutex.synchronize { processors.delete_at(pi) }
                pi -= 1
              end
            end
            pi += 1
          end
          ei += 1
        end
        debug "Events processing finished. #{dump_state}"
      end

      def debug(msg)
        puts "[#{time}] DEBUG #{msg}" if opts[:debug]
      end

      def info(msg)
        puts "[#{time}] INFO #{msg}"
      end

      def time
        Time.now.strftime("%Y-%m-%d %H:%M:%S")
      end
    end
  end

end

