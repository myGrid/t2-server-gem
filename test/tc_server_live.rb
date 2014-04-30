# Copyright (c) 2010-2013 The University of Manchester, UK.
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
#  * Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
#  * Neither the names of The University of Manchester nor the names of its
#    contributors may be used to endorse or promote products derived from this
#    software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# Author: Robert Haines

require 't2-server'

class TestServer < Test::Unit::TestCase

  def test_server_connection
    assert_nothing_raised(T2Server::ConnectionError) do
      T2Server::Server.new($uri, $conn_params)
    end
  end

  def test_server_connection_no_params
    assert_nothing_raised(T2Server::ConnectionError) do
      T2Server::Server.new($uri)
    end
  end

  def test_run_creation
    T2Server::Server.new($uri, $conn_params) do |server|
      assert_nothing_raised(T2Server::T2ServerError) do
        run = server.create_run($wkf_pass, $creds)
        run.delete
      end
    end
  end

  # Need to do these together so testing the limit is cleaned up!
  def test_server_limits_delete_all
    T2Server::Server.new($uri, $conn_params) do |server|
      limit = server.run_limit($creds)
      max_runs = 0
      assert_instance_of(Fixnum, limit)
      assert_raise(T2Server::ServerAtCapacityError) do
        # Detect the concurrent run limit and
        # add 1 just in case there are no runs at this point
        more = true
        (limit + 1).times do
          run = server.create_run($wkf_pass, $creds)
          if more
            run.input_port("IN").value = "Hello"
            more = run.start
            if more
              max_runs += 1
              assert(run.running?)
            else
              assert(run.initialized?)
            end
          end
        end
      end

      assert(max_runs <= limit)

      assert_nothing_raised(T2Server::T2ServerError) do
        server.delete_all_runs($creds)
      end
    end
  end
end
