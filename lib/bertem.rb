require 'bertrpc'
require 'eventmachine'

require 'bertem/action'
require 'bertem/bertrpc'

module BERTEM
  def self.version
    File.read(File.join(File.dirname(__FILE__), *%w[.. VERSION])).chomp
  rescue
    'unknown'
  end

  VERSION = self.version
end