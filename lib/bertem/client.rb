require 'bertrpc'
require 'logger'
require 'eventmachine'

module BERTEM
  # NOTE: ernie (and all other BERTRPC servers?) closes connections after
  #       responding, so we can't send multiple requests per connection.
  #       Hence, the default for persistent is false.  If you are dealing
  #       with a more sophisticated server that supports more than one
  #       request per connection, call BERTEM.service with
  #       persistent = true and it should Just Work.

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
      attr_accessor :persistent
    end
    
    self.persistent = false

    def self.service(host, port, persistent = false, timeout = nil)
      self.persistent = persistent
      c = EM.connect(host, port, self)
      c.pending_connect_timeout = timeout if timeout
      c
    end

    def post_init
      @requests = []
    end

    def persistent
      Client.persistent
    end

    def receive_data(bert_response)
      # This needs to be much more intelligent (retain a buffer, append new response data
      # to the buffer, remember the length of the msg it is working with if it is incomplete,
      # etc.)
      while bert_response.length > 4 do
        raise BERTRPC::ProtocolError.new(BERTRPC::ProtocolError::NO_HEADER) unless bert_response.length > 4
        len = bert_response.slice!(0..3).unpack('N').first # just here to strip the length header
        raise BERTRPC::ProtocolError.new(BERTRPC::ProtocolError::NO_DATA) unless bert_response.length > 0
        bert = bert_response.slice!(0..(len - 1))
        @requests.pop.succeed(decode_bert_response(bert))
        unless persistent
          close_connection
          break
        end
      end
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
