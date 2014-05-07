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

class TestServer < Test::Unit::TestCase
  include T2Server::Mocks

  # Need to lock down the run UUID so recorded server responses make sense.
  RUN_UUID = "a341b87f-25cc-4dfd-be36-f5b073a6ba74"

  def setup
    @server = T2Server::Server.new($uri, $conn_params)

    # Register common mocks.
    @mock_rest = mock("/rest/", :accept => "application/xml",
      :output => "get-rest.raw")
    @mock_policy = mock("/rest/policy", :accept => "application/xml",
      :output => "get-rest-policy.raw")
    mock("/rest/runs", :method => :post, :credentials => $userinfo,
      :status => 201,
      :location => "http://localhost/taverna/rest/runs/#{RUN_UUID}")
  end

  def test_run_creation
    assert_nothing_raised(T2Server::T2ServerError) do
      run = @server.create_run($wkf_pass, $creds)

      # Mock the deletion of this specific run.
      mock("/rest/runs/#{run.id}", :method => :delete,
        :credentials => $userinfo, :status => 204)

      run.delete
    end

    # Make sure we don't keep fetching this information.
    assert_requested @mock_rest, :times => 1
    assert_requested @mock_policy, :times => 1
  end

  def test_server_limits_delete_all
    # Mock specific routes for these tests.
    mock_limit = mock("/rest/policy/runLimit", :accept => "text/plain",
      :credentials => $userinfo, :output => "get-rest-policy-runlimit.raw")

    limit = @server.run_limit($creds)
    assert_instance_of(Fixnum, limit)

    # Mock creation of a run to work once then fail due to server capacity.
    mock("/rest/runs", :method => :post, :credentials => $userinfo,
      :status => [201, 503],
      :location => "http://localhost/taverna/rest/runs/#{RUN_UUID}")



    run = nil
    assert_nothing_raised(T2Server::ServerAtCapacityError) do
      run = @server.create_run($wkf_pass, $creds)
    end
    assert_raise(T2Server::ServerAtCapacityError) do
      @server.create_run($wkf_pass, $creds)
    end

    assert_equal RUN_UUID, run.id

    mock("/rest/runs", :accept => "application/xml",
      :credentials => $userinfo, :output => "get-rest-runs.raw")

    assert_equal 1, @server.runs($creds).length

    # Mock for this specific run.
    run_uri = "/rest/runs/#{run.id}"
    mock_run = mock(run_uri, :accept => "application/xml",
      :credentials => $userinfo, :output => "get-rest-run.raw")
    mock_input = mock("#{run_uri}/input", :accept => "application/xml",
      :credentials => $userinfo, :output => "get-rest-run-input.raw")
    mock_status = mock("#{run_uri}/status", :accept => "text/plain",
      :credentials => $userinfo, :output => "get-rest-run-status.raw")
    mock_input_exp = mock("#{run_uri}/input/expected",
      :accept => "application/xml", :credentials => $userinfo,
      :output => "get-rest-run-input-expected.raw")

    # Mock starting a run to fail due to concurrent running limit.
    mock_run_start = mock("#{run_uri}/status", :method => :put,
      :status => 503, :credentials => $userinfo, :body => "Operating")

    # Running limit reached: Run#start should return false and run should stay
    # in the initialized state.
    refute run.start
    assert_equal :initialized, run.status

    # Delete all runs but just need to mock deletion of the one run.
    mock(run_uri, :method => :delete, :credentials => $userinfo,
      :status => 204)

    assert_nothing_raised(T2Server::T2ServerError) do
      @server.delete_all_runs($creds)
    end

    # Make sure we don't keep fetching this information.
    assert_requested @mock_rest, :times => 1
    assert_requested @mock_policy, :times => 1
    assert_requested mock_limit, :times => 1
    assert_requested mock_run, :times => 1
  end

end
