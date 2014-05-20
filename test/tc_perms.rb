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

class TestPermissions < Test::Unit::TestCase
  include T2Server::Mocks

  WKF_PASS = "test/workflows/pass_through.t2flow"

  # Need to lock down the run UUID so recorded server responses make sense.
  RUN_UUID = "a341b87f-25cc-4dfd-be36-f5b073a6ba74"
  RUN_PATH = "/rest/runs/#{RUN_UUID}"

  def setup
    # Register common mocks.
    mock("/rest/", :accept => "application/xml", :output => "get-rest.raw")
    mock("/rest/policy", :accept => "application/xml",
      :output => "get-rest-policy.raw")
    mock("/rest/runs", :method => :post, :credentials => $userinfo,
      :status => 201,
      :location => "https://localhost/taverna#{RUN_PATH}")
    mock(RUN_PATH, :accept => "application/xml", :credentials => $userinfo,
      :output => "get-rest-run.raw")
    mock("#{RUN_PATH}/input", :accept => "application/xml",
      :credentials => $userinfo, :output => "get-rest-run-input.raw")
    mock("#{RUN_PATH}/status", :accept => "text/plain",
      :credentials => $userinfo, :output => "get-rest-run-status.raw")
    mock("#{RUN_PATH}/security", :accept => "application/xml",
      :credentials => $userinfo, :output => "get-rest-run-security.raw")
  end

  def test_ownership
    T2Server::Run.create($uri, WKF_PASS, $creds, $conn_params) do |run|
      assert run.owner?
      assert_equal $creds.username, run.owner
      assert_not_equal $creds1.username, run.owner
    end
  end

  def test_grant_and_revocation
    mock("/rest/runs", :accept => "application/xml",
      :credentials => $userinfo1, :output => "get-rest-runs.raw")
    mock(RUN_PATH, :accept => "application/xml", :credentials => $userinfo1,
      :output => "get-rest-run.raw")
    mock("#{RUN_PATH}/security/permissions", :accept => "application/xml",
      :credentials => $userinfo,
      :output => "get-rest-run-security-permissions.raw")
    mock("#{RUN_PATH}/security/permissions", :method => :post, :status => 201,
      :credentials => $userinfo,
      :location => "https://localhost/taverna#{RUN_PATH}/security/permissions/#{$creds1.username}")
    mock("#{RUN_PATH}/security/permissions/#{$creds1.username}",
      :method => :delete, :credentials => $userinfo, :status => 204)

    T2Server::Run.create($uri, WKF_PASS, $creds, $conn_params) do |run|
      assert_equal :none, run.permission($creds1.username)

      run.grant_permission($creds1.username, :read)

      run1 = run.server.run(run.id, $creds1)
      refute run1.owner?
      assert_not_equal $creds1.username, run1.owner
      assert_equal $creds.username, run1.owner

      # Can't do permissions stuff if not the run's owner.
      refute run1.grant_permission($creds1.username, :update)
      refute run1.revoke_permission($creds1.username)

      assert run.revoke_permission($creds1.username)
    end
  end

end
