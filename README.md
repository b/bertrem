BERTEM
======

By Benjamin Black (b@b3k.us)

BERTEM is a BERT-RPC client and server implementation that uses an EventMachine server to accept incoming connections, and then delegates the request to loadable Ruby handlers.  BERTEM is derived from [Ernie](http://github.com/mojombo/ernie), by Tom Preston-Warner.

See the full BERT-RPC specification at [bert-rpc.org](http://bert-rpc.org).

BERTEM currently supports the following BERT-RPC features:

* `call` requests
* `cast` requests


Installation
------------

	$ git clone git://github.com/b/bertem.git && cd bertem
	$ rake build
    $ gem install pkg/bertem-0.0.3.gem


Example Handler
---------------

A simple Ruby module for use in a BERTEM server:

    require 'bertem'
    
    module Calc
      def add(a, b)
        a + b
      end
    end


Example Server
--------------

A simple BERTEM server using the Calc module defined above:

	require 'bertem'

	EM.run {
	  BERTEM::Server.expose(:calc, Calc)
	  svc = BERTEM::Server.start('localhost', 9999)
	}
	
	
Logging
-------

You can have logging sent to a file by adding these lines to your handler:

    logfile('/var/log/bertem.log')
    loglevel(Logger::INFO)

This will log startup info, requests, and error messages to the log. Choosing
Logger::DEBUG will include the response (be careful, doing this can generate
very large log files).


Example BERT-RPC call for above example
---------------------------------------

    -> {call, calc, add, [1, 2]}

    <- {reply, 3}


Using the BERTRPC gem to make calls to BERTEM
---------------------------------------------

The BERTEM client supports persistent connections, so you can send multiple requests over the same service connection and responses will return in the order the requests were sent:

	require 'bertem'
	
	EM.run {
	  client = BERTEM::Client.service('localhost', 9999, true)
	  rpc = client.call.calc.add(6, 2)
	  rpc.callback { |res|
	    puts "Got response! -> #{res}"
	  }
  
	  rpc = client.call.calc.add(2, 2)
	  rpc.callback { |res|
	    puts "Got response! -> #{res}"
	  }
	}

Alternatively, you can make BERT-RPC calls from Ruby with the [BERTRPC gem](http://github.com/mojombo/bertrpc):

    require 'bertrpc'

    svc = BERTRPC::Service.new('localhost', 8000)
    svc.call.calc.add(1, 2)
    # => 3


Contribute
----------

If you'd like to hack on BERTEM, start by forking my repo on GitHub:

    http://github.com/b/bertem

To get all of the dependencies, install the gem first

The best way to get your changes merged back into core is as follows:

1. Clone down your fork
1. Create a topic branch to contain your change
1. Hack away
1. Add tests and make sure everything still passes by running `rake`
1. If you are adding new functionality, document it in the README.md
1. Do not change the version number, I will do that on my end
1. If necessary, rebase your commits into logical chunks, without errors
1. Push the branch up to GitHub
1. Send me (b) a pull request for your branch


Copyright
---------

Copyright (c) 2009 Benjamin Black. See LICENSE for details.
