module BERTRPC
  class Action
    
    undef_method :execute
    undef_method :write
    undef_method :transaction
    undef_method :connect_to
    
    def execute
      transaction(encode_ruby_request(t[@req.kind, @mod, @fun, @args]))
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