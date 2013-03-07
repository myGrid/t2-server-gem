# Copyright (c) 2010-2012 The University of Manchester, UK.
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

class TestPermissions < Test::Unit::TestCase

  def test_ownership_and_revokation
    server = T2Server::Server.new($uri, $conn_params)

    server.create_run($wkf_pass, $creds) do |run|
      assert(run.owner?)
      assert_equal(run.owner, $creds.username)

      assert_equal(run.permission($creds1.username), :none)
      run.grant_permission($creds1.username, :read)
      assert_equal(run.permission($creds1.username), :read)
      run_id = run.identifier
      run1 = server.run(run_id, $creds1)

      assert(!run1.owner?)
      assert_not_equal(run1.owner, $creds1.username)

      assert(run.revoke_permission($creds1.username))
      assert_equal(run.permission($creds1.username), :none)
      assert(run.revoke_permission($creds1.username))

      assert(run.delete)
    end
  end

  def test_read_permission
    server = T2Server::Server.new($uri, $conn_params)

    server.create_run($wkf_pass, $creds) do |run|
      assert_nothing_raised(T2Server::AccessForbiddenError) do
        run.grant_permission($creds1.username, :read)
      end

      run_id = run.identifier

      run1 = nil
      assert_nothing_raised(T2Server::AccessForbiddenError) do
        run1 = server.run(run_id, $creds1)
      end

      assert_raise(T2Server::AccessForbiddenError) do
        run1.input_port("IN").value = "Hello, World!"
        run1.start
      end

      run.input_port("IN").value = "Hello, World!"
      run.start
      run.wait

      assert_nothing_raised(T2Server::AccessForbiddenError) do
        run1.output_port("OUT").value
      end

      assert_raise(T2Server::AccessForbiddenError) do
        run1.delete
      end

      assert_nothing_raised(T2Server::AccessForbiddenError) do
        run.delete
      end
    end
  end

  def test_update_permission
    server = T2Server::Server.new($uri, $conn_params)

    server.create_run($wkf_pass, $creds) do |run|
      assert_nothing_raised(T2Server::AccessForbiddenError) do
        run.grant_permission($creds1.username, :update)
      end

      run_id = run.identifier

      run1 = nil
      assert_nothing_raised(T2Server::AccessForbiddenError) do
        run1 = server.run(run_id, $creds1)
        run1.input_port("IN").value = "Hello, World!"
        run1.start
        run1.wait
        run1.output_port("OUT").value
      end

      assert_raise(T2Server::AccessForbiddenError) do
        run1.delete
      end

      assert_nothing_raised(T2Server::AccessForbiddenError) do
        run.delete
      end
    end
  end

  def test_destroy_permission
    server = T2Server::Server.new($uri, $conn_params)

    server.create_run($wkf_pass, $creds) do |run|
      assert_nothing_raised(T2Server::AccessForbiddenError) do
        run.grant_permission($creds1.username, :destroy)
      end

      run_id = run.identifier

      assert_nothing_raised(T2Server::AccessForbiddenError) do
        run1 = server.run(run_id, $creds1)
        run1.input_port("IN").value = "Hello, World!"
        run1.start
        run1.wait
        run1.output_port("OUT").value
        run1.delete
      end
    end
  end
end
