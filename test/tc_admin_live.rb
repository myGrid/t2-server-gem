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

class TestAdmin < Test::Unit::TestCase

  def test_admin
    T2Server::Server.new($uri, $conn_params) do |server|

      # Test for a user that we know isn't configured on the server.
      assert_raise(T2Server::AuthorizationError) do
        server.administrator(T2Server::HttpBasic.new("u", "p"))
      end

      # Test for a user that is in the system but may or may not be a
      # superuser. If the user is not a superuser then don't perform any more
      # tests on the admin resource.
      begin
        server.administrator($creds)
      rescue T2Server::AccessForbiddenError => e
        # ignore, just don't run more tests
        return
      end

      server.administrator($creds) do |admin|
        assert_equal(admin["allownew"].name, "allowNew")

        save = admin["allownew"].value
        admin["allownew"].value = false
        assert_equal(admin["allownew"].value, "false")
        admin["allownew"].value = save
        assert_equal(admin["allownew"].value, save)
      end
    end
  end
end
