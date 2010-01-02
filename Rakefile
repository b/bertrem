require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "bertrem"
    gem.summary = %Q{BERTREM is a Ruby EventMachine BERT-RPC client and server library.}
    gem.email = "b@b3k.us"
    gem.homepage = "http://github.com/b/bertrem"
    gem.authors = ["Benjamin Black"]
    gem.add_dependency('bertrpc', '>= 1.1.2', '< 2.0.0')
    gem.add_dependency('eventmachine')
    # gem is a Gem::Specification...
    # see http://www.rubygems.org/read/chapter/20 for additional settings
  end

rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

task :console do
  exec('irb -Ilib -rbertrpc')
end