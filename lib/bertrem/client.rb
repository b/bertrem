require 'bertrpc'
require 'logger'
require 'eventmachine'

module BERTREM
  # NOTE: ernie closes connections after responding, so we can't send
  #       multiple requests per connection.  Hence, the default for
  #       persistent is false.  If you are working with a server that
  #       supports more than one request per connection, like
  #       BERTREM::Server, call BERTREM.service with persistent = true
  #       and it will Just Work.
  class Client < EventMachine::Connection
    include BERTRPC::Encodes

    attr_accessor :requests

    class Request
      attr_accessor :kind, :options

      def initialize(svc, kind, options)
        @svc = svc
        @kind = kind
        @options = options
      end

      def method_missing(cmd, *args)
        BERTRPC::Mod.new(@svc, self, cmd)
      end

    end

    class << self
      attr_accessor :persistent, :err_callback
    end

    self.persistent = false
    self.err_callback = Proc.new {|msg| raise BERTREM::ConnectionError.new(msg)}
    
    def self.service(host, port, persistent = false, timeout = nil)
      self.persistent = persistent
      c = EM.connect(host, port, self)
      c.pending_connect_timeout = timeout if timeout
      c
    end

    def post_init
      @receive_buf = ""; @receive_len = 0; @more = false
      @requests = []
    end

    def unbind
      super
      @receive_buf = ""; @receive_len = 0; @more = false
      (@requests || []).each {|r| r.fail}
      Client.err_callback.call("Connection to server lost!") if error?
    end

    def persistent
      Client.persistent
    end

    def receive_data(bert_response)
      @receive_buf << bert_response

      while @receive_buf.length > 0
        unless @more
          begin
            if @receive_buf.length > 4
              @receive_len = @receive_buf.slice!(0..3).unpack('N').first if @receive_len == 0
              raise BERTRPC::ProtocolError.new(BERTRPC::ProtocolError::NO_DATA) unless @receive_buf.length > 0
            else
              raise BERTRPC::ProtocolError.new(BERTRPC::ProtocolError::NO_HEADER)
            end
          rescue Exception => e
            log "Bad BERT message: #{e.message}"
            next       
          end
        end

        if @receive_buf.length >= @receive_len
          bert = @receive_buf.slice!(0..(@receive_len - 1))
          @receive_len = 0; @more = false
          @requests.pop.succeed(decode_bert_response(bert))
          break unless persistent
        else
          @more = true
          break
        end
      end

      close_connection unless (persistent || @more)
    end

    def call(options = nil)
      verify_options(options)
      Request.new(self, :call, options)
    end

    def cast(options = nil)
      verify_options(options)
      Request.new(self, :cast, options)
    end

    def verify_options(options)
      if options
        if cache = options[:cache]
          unless cache[0] == :validation && cache[1].is_a?(String)
            raise BERTRPC::InvalidOption.new("Valid :cache args are [:validation, String]")
          end
        else
          raise BERTRPC::InvalidOption.new("Valid options are :cache")
        end
      end
    end

  end

end

class BERTREM::ConnectionError < StandardError ; end