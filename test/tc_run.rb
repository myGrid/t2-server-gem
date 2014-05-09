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

# For time-based tests to run we have to mangle the timezone to match the
# local server. Sigh.
def timezone
  z = Time.zone_offset(Time.now.zone) / 3600
  s = z.abs < 10 ? "0#{z.abs.to_s}" : z.abs.to_s
  z < 0 ? "-#{s}" : "+#{s}"
end

class TestRun < Test::Unit::TestCase
  include T2Server::Mocks

  WKF_PASS = "test/workflows/pass_through.t2flow"

  # Some expiry times, mangled to work in different timezones.
  TIME_STR = "2014-05-08 17:41:57 #{timezone}00"    # Ruby time format
  TIME_RET = "2014-05-08T17:41:57.00#{timezone}:00" # Server return format
  TIME_SET = "2014-05-08T17:41:57.00#{timezone}00"  # Server update format

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
  end

  # Test run connection
  def test_run_create_and_delete
    del = mock(RUN_PATH, :method => :delete, :status => [204, 404, 404],
      :credentials => $userinfo)

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

    assert_requested del, :times => 3
  end

  # Test run naming.
  def test_run_naming
    mock("#{RUN_PATH}/name", :accept => "text/plain",
      :credentials => $userinfo, :output => "get-rest-run-name.raw")

    T2Server::Server.new($uri, $conn_params) do |server|
      server.create_run(WKF_PASS, $creds) do |run|
        # Read initial name.
        assert run.name.length > 0
        assert_equal "Workflow1", run.name

        # Set a new name.
        name = "No input or output"

        mock("#{RUN_PATH}/name", :method => :put, :body => name,
          :credentials => $userinfo)

        assert run.name = name

        # Set a name that is too long. The mock should only see the first 48
        # characters.
        long_name = "0123456789012345678901234567890123456789ABCDEFGHIJ"

        mock("#{RUN_PATH}/name", :method => :put, :body => long_name[0...48],
          :credentials => $userinfo)

        assert run.name = long_name
      end
    end
  end

  def test_get_expiry
    mock("#{RUN_PATH}/expiry", :accept => "text/plain", :body => TIME_RET,
      :credentials => $userinfo)

    run = T2Server::Run.create($uri, WKF_PASS, $creds, $conn_params)

    exp = run.expiry
    assert exp.instance_of?(Time)
  end

  def test_update_expiry
    exp = mock("#{RUN_PATH}/expiry", :method => :put, :accept => "*/*",
      :body => TIME_SET, :credentials => $userinfo)

    run = T2Server::Run.create($uri, WKF_PASS, $creds, $conn_params)

    run.expiry = TIME_STR
    run.expiry = Time.parse(TIME_STR)

    assert_requested exp, :times => 2
  end

  # Upload workflow as a string, then test getting it back.
  def test_get_workflow
    workflow = File.read(WKF_PASS)

    wkf = mock("#{RUN_PATH}/workflow", :body => workflow,
      :accept => "application/xml", :credentials => $userinfo)

    T2Server::Run.create($uri, workflow, $creds, $conn_params) do |run|
      # Download twice to check it's only actually retrieved once.
      assert_equal workflow, run.workflow
      assert_equal workflow, run.workflow
    end

    assert_requested wkf, :times => 1
  end

end
