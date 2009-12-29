require 'bert'
require 'logger'
require 'eventmachine'

module BERTEM
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
    def dispatch(mod, fun, args)
      Server.mods[mod] || raise(ServerError.new("No such module '#{mod}'"))
      Server.mods[mod].funs[fun] || raise(ServerError.new("No such function '#{mod}:#{fun}'"))
      Server.mods[mod].funs[fun].call(*args)
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
      Server.log.info("(#{Process.pid}) Starting")
      Server.log.debug(Server.mods.inspect)  
    end
    
    # Receive data on the connection.
    #
    def receive_data(data)
      # This needs to be much more intelligent (retain a buffer, append new request data
      # to the buffer, remember the length of the msg it is working with if it is incomplete,
      # etc.)
      while data.length > 4 do
        raw = data.slice!(0..3)
        puts "Could not find BERP length header.  Weird, huh?" unless raw
        packet_size = raw.unpack('N').first
        puts "Could not understand BERP packet length.  What gives?" unless packet_size
        bert = data.slice!(0..(packet_size - 1))
        iruby = BERT.decode(bert)
        
        unless iruby
          Server.log.info("(#{Process.pid}) No Ruby in this here packet.  On to the next one...")
          next
        end

        if iruby.size == 4 && iruby[0] == :call
          mod, fun, args = iruby[1..3]
          Server.log.info("-> " + iruby.inspect)
          begin
            res = dispatch(mod, fun, args)
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
          Server.log.info("-> " + [:cast, mod, fun, args].inspect)
          begin
            dispatch(mod, fun, args)
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
      end
    end
  end
    
end

class BERTEM::ServerError < StandardError; end
