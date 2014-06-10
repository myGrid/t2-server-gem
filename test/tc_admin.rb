# Copyright (c) 2014 The University of Manchester, UK.
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

require 'mocked-server-responses/mocks'
require 't2-server'

class TestAdmin < Test::Unit::TestCase
  include T2Server::Mocks

  def setup
    @server = T2Server::Server.new($uri, $conn_params)

    mock("/admin", :accept => "application/xml", :output => "get-admin.raw",
      :credentials => $userinfo)
    mock("/admin/allowNew", :method => :options, :credentials => $userinfo,
      :output => "options-admin-allownew.raw")
  end

  def test_admin_init
    @server.administrator($creds) do |admin|
      assert_not_nil admin["allowNew"]
      assert_nil admin["__not-here__"]
    end
  end

  def test_admin_resource
    @server.administrator($creds) do |admin|
      resource = admin["allownew"]

      assert_not_nil resource
      assert_equal "allowNew", resource.name
      assert resource.writable?
      assert resource.respond_to?(:value=)

      rEsOuRcE = admin["AlLOwnEW"]
      assert_not_nil rEsOuRcE
      assert_same resource, rEsOuRcE
    end
  end

  def test_admin_read
    value = ["true", "false"]
    mock("/admin/allowNew", :credentials => $userinfo, :accept => "text/plain",
      :body => value)

    @server.administrator($creds) do |admin|
      resource = admin["allownew"]

      # Test that the value is fetched from the server each time.
      assert_equal value[0], resource.value
      assert_equal value[1], resource.value
    end
  end

  def test_admin_write
    value = false
    mock("/admin/allowNew", :method => :put, :credentials => $userinfo,
      :body => value.to_s, :status => 200)

    @server.administrator($creds) do |admin|
      resource = admin["allownew"]
      resource.value = value
    end
  end
end
