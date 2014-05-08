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

class TestRun < Test::Unit::TestCase
  include T2Server::Mocks

  WKF_PASS = "test/workflows/pass_through.t2flow"

  # Need to lock down the run UUID so recorded server responses make sense.
  RUN_UUID = "a341b87f-25cc-4dfd-be36-f5b073a6ba74"

  def setup
    # Register common mocks.
    mock("/rest/", :accept => "application/xml", :output => "get-rest.raw")
    mock("/rest/policy", :accept => "application/xml",
      :output => "get-rest-policy.raw")
    mock("/rest/runs", :method => :post, :credentials => $userinfo,
      :status => 201,
      :location => "https://localhost/taverna/rest/runs/#{RUN_UUID}")
    mock("/rest/runs/#{RUN_UUID}", :accept => "application/xml",
      :credentials => $userinfo, :output => "get-rest-run.raw")
    mock("/rest/runs/#{RUN_UUID}/input", :accept => "application/xml",
      :credentials => $userinfo, :output => "get-rest-run-input.raw")
    mock("/rest/runs/#{RUN_UUID}/status", :accept => "text/plain",
      :credentials => $userinfo, :output => "get-rest-run-status.raw")
    mock("/rest/runs/#{RUN_UUID}", :method => :delete, :status => 204,
      :credentials => $userinfo)
  end

  # Test run connection
  def test_run_create_and_delete
    assert_nothing_raised(T2Server::ConnectionError) do
      run = T2Server::Run.create($uri, WKF_PASS, $creds, $conn_params)
      assert run.initialized?
      assert run.delete
      assert run.deleted?
      assert_nothing_raised(T2Server::AttributeNotFoundError) do
        assert run.delete # Should still return true, not raise 404
      end
      assert run.delete # Should still return true
    end
  end

end
