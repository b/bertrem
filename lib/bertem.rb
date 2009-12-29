require 'logger'
require 'bertrpc'
require 'eventmachine'

require 'bertem/action'
require 'bertem/mod'
require 'bertem/client'
require 'bertem/server'

module BERTEM
  def self.version
    File.read(File.join(File.dirname(__FILE__), *%w[.. VERSION])).chomp
  rescue
    'unknown'
  end

  VERSION = self.version
end