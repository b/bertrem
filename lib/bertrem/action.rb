require 'eventmachine'
require 'bertrpc'

module BERTRPC
  class Action

    [:execute, :write, :transaction, :connect_to].each do |m|
      remove_method m if method_defined?(m)
    end

    def execute
      transaction(encode_ruby_request(t[@req.kind, @mod, @fun, @args]))
      @svc.requests.unshift(EM::DefaultDeferrable.new).first
    end

    def write(bert)
      @svc.send_data([bert.length].pack("N"))
      @svc.send_data(bert)
    end

    def transaction(bert_request)
      if @req.options
        if @req.options[:cache] && @req.options[:cache][0] == :validation
          token = @req.options[:cache][1]
          info_bert = encode_ruby_request([:info, :cache, [:validation, token]])
          write(info_bert)
        end
      end

      write(bert_request)
    end

  end
end
