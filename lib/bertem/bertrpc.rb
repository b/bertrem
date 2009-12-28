module EventMachine
  module Protocols

    # = Example
    # EM.run{
    #   svc = EM::Protocols::BERTRPC.connect('localhost', 9999)
    #
    #   req = svc.call.calc.add(1, 2)
    #   req.callback{ |res|
    #     p(res)
    #   }
    # }

    class BERTRPC < EventMachine::Connection
      include ::BERTRPC::Encodes

      attr_accessor :requests
      
      class Request
        attr_accessor :kind, :options

        def initialize(svc, kind, options)
          @svc = svc
          @kind = kind
          @options = options
        end

        def method_missing(cmd, *args)
          ::BERTRPC::Mod.new(@svc, self, cmd)
        end

      end

      def self.connect(host, port, timeout = nil)
        EM.connect(host, port, self)
      end

      def post_init
				@requests = []
      end

      def receive_data(bert_response)
        raise ::BERTRPC::ProtocolError.new(::BERTRPC::ProtocolError::NO_HEADER) unless bert_response.length > 4
        len = bert_response.slice!(0..3).unpack('N').first # just here to strip the length header
        raise ::BERTRPC::ProtocolError.new(::BERTRPC::ProtocolError::NO_DATA) unless bert_response.length > 0
        @response = decode_bert_response(bert_response)
        @requests.pop.succeed(@response)
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
              raise ::BERTRPC::InvalidOption.new("Valid :cache args are [:validation, String]")
            end
          else
            raise ::BERTRPC::InvalidOption.new("Valid options are :cache")
          end
        end
      end

    end

  end
end
