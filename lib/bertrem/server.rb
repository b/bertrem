require 'bert'
require 'logger'
require 'eventmachine'

module BERTREM
  class Server < EventMachine::Connection
    include BERTRPC::Encodes

    # This class derived from Ernie/ernie.rb

    class << self
      attr_accessor :mods, :current_mod, :log
    end

    self.mods = {}
    self.current_mod = nil
    self.log = Logger.new(STDOUT)
    self.log.level = Logger::INFO

    def self.start(host, port)
      EM.start_server(host, port, self)
    end

    # Record a module.
    #   +name+ is the module Symbol
    #   +block+ is the Block containing function definitions
    #
    # Returns nothing
    def self.mod(name, block)
      m = Mod.new(name)
      self.current_mod = m
      self.mods[name] = m
      block.call
    end

    # Record a function.
    #   +name+ is the function Symbol
    #   +block+ is the Block to associate
    #
    # Returns nothing
    def self.fun(name, block)
      self.current_mod.fun(name, block)
    end

    # Expose all public methods in a Ruby module:
    #   +name+ is the ernie module Symbol
    #   +mixin+ is the ruby module whose public methods are exposed
    #
    # Returns nothing
    def self.expose(name, mixin)
      context = Object.new
      context.extend mixin
      self.mod(name, lambda {
        mixin.public_instance_methods.each do |meth|
          self.fun(meth.to_sym, context.method(meth))
        end
      })
      context
    end

    # Set the logfile to given path.
    #   +file+ is the String path to the logfile
    #
    # Returns nothing
    def self.logfile(file)
      self.log = Logger.new(file)
    end

    # Set the log level.
    #   +level+ is the Logger level (Logger::WARN, etc)
    #
    # Returns nothing
    def self.loglevel(level)
      self.log.level = level
    end

    # Dispatch the request to the proper mod:fun.
    #   +mod+ is the module Symbol
    #   +fun+ is the function Symbol
    #   +args+ is the Array of arguments
    #
    # Returns the Ruby object response
    def self.dispatch(mod, fun, args)
      mods[mod] || raise(ServerError.new("No such module '#{mod}'"))
      mods[mod].funs[fun] || raise(ServerError.new("No such function '#{mod}:#{fun}'"))
      mods[mod].funs[fun].call(*args)
    end

    # Write the given Ruby object to the wire as a BERP.
    #   +output+ is the IO on which to write
    #   +ruby+ is the Ruby object to encode
    #
    # Returns nothing
    def write_berp(ruby)
      data = BERT.encode(ruby)
      send_data([data.length].pack("N"))
      send_data(data)
    end

    def post_init
      @receive_buf = ""; @receive_len = 0; @more = false
      #start_tls(:private_key_file => '/tmp/server.key', :cert_chain_file => '/tmp/server.crt', :verify_peer => false)
      Server.log.info("(#{Process.pid}) Starting")
      Server.log.debug(Server.mods.inspect)
    end

    # Receive data on the connection.
    #
    def receive_data(bert_request)
      @receive_buf << bert_request

      while @receive_buf.length > 0 do
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
          iruby = BERT.decode(bert)

          unless iruby
            Server.log.info("(#{Process.pid}) No Ruby in this here packet.  On to the next one...")
            next
          end

          if iruby.size == 4 && iruby[0] == :call
            mod, fun, args = iruby[1..3]
            Server.log.debug("-> " + iruby.inspect)
            begin
              res = Server.dispatch(mod, fun, args)
              oruby = t[:reply, res]
              Server.log.debug("<- " + oruby.inspect)
              write_berp(oruby)
            rescue ServerError => e
              oruby = t[:error, t[:server, 0, e.class.to_s, e.message, e.backtrace]]
              Server.log.error("<- " + oruby.inspect)
              Server.log.error(e.backtrace.join("\n"))
              write_berp(oruby)
            rescue Object => e
              oruby = t[:error, t[:user, 0, e.class.to_s, e.message, e.backtrace]]
              Server.log.error("<- " + oruby.inspect)
              Server.log.error(e.backtrace.join("\n"))
              write_berp(oruby)
            end
          elsif iruby.size == 4 && iruby[0] == :cast
            mod, fun, args = iruby[1..3]
            Server.log.debug("-> " + [:cast, mod, fun, args].inspect)
            begin
              Server.dispatch(mod, fun, args)
            rescue Object => e
              # ignore
            end
            write_berp(t[:noreply])
          else
            Server.log.error("-> " + iruby.inspect)
            oruby = t[:error, t[:server, 0, "Invalid request: #{iruby.inspect}"]]
            Server.log.error("<- " + oruby.inspect)
            write_berp(oruby)
          end
        else
          @more = true
          break
        end
      end
    end
  end

end

class BERTREM::ServerError < StandardError; end
