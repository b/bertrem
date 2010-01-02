module BERTREM
  class Mod
    
    attr_accessor :name, :funs

    def initialize(name)
      self.name = name
      self.funs = {}
    end

    def fun(name, block)
      raise TypeError, "block required" if block.nil?
      self.funs[name] = block
    end
    
  end
  
end