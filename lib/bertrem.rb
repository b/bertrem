require 'logger'
require 'bertrpc'
require 'eventmachine'

require 'bertrem/action'
require 'bertrem/mod'
require 'bertrem/client'
require 'bertrem/server'

module BERTREM
  def self.version
    File.read(File.join(File.dirname(__FILE__), *%w[.. VERSION])).chomp
  rescue
    'unknown'
  end

  VERSION = self.version
end