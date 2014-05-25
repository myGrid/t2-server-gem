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

class TestInteractions < Test::Unit::TestCase
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
    mock("#{RUN_PATH}/security", :accept => "application/xml",
      :credentials => $userinfo, :output => "get-rest-run-security.raw")

    @run = T2Server::Run.create($uri, WKF_PASS, $creds, $conn_params)
  end

  def test_empty_feed
    mock("#{RUN_PATH}/interaction", :accept => "application/atom+xml",
      :credentials => $userinfo,
      :output => "get-rest-run-interaction-feed-0.raw")
    assert_equal [], @run.notifications(:all)
  end

  def test_requests
    mock("#{RUN_PATH}/interaction", :accept => "application/atom+xml",
      :credentials => $userinfo,
      :output => "get-rest-run-interaction-feed-1.raw")

    entries = @run.notifications(:all)
    requests = @run.notifications(:requests)
    replies = @run.notifications(:replies)

    assert_equal 2, entries.length
    assert_equal 2, requests.length
    assert_equal [], replies

    # No new requests...
    assert_equal [], @run.notifications

    entries.each do |entry|
      refute entry.is_reply?
      refute entry.is_notification?
      refute entry.has_reply?
      assert_not_equal "", entry.serial
      assert_not_nil entry.uri
      assert_nil entry.reply_to
    end

    test_input_data = "{ \"test\" : \"value\"}"
    mock("#{RUN_PATH}/wd/interactions/interaction#{entries[0].id}InputData.json",
      :credentials => $userinfo, :body => test_input_data)

    assert_equal test_input_data, entries[0].input_data
  end

  def test_no_request_input_data
    mock("#{RUN_PATH}/interaction", :accept => "application/atom+xml",
      :credentials => $userinfo,
      :output => "get-rest-run-interaction-feed-1.raw")

    entries = @run.notifications

    mock("#{RUN_PATH}/wd/interactions/interaction#{entries[0].id}InputData.json",
      :credentials => $userinfo, :body => "", :status => 404)

    assert_nothing_raised(T2Server::AttributeNotFoundError) do
      assert_equal "", entries[0].input_data
    end
  end

  def test_replies
    mock("#{RUN_PATH}/interaction", :accept => "application/atom+xml",
      :credentials => $userinfo,
      :output => "get-rest-run-interaction-feed-1.raw")

    entries = @run.notifications(:all)
    requests = @run.notifications(:requests)
    replies = @run.notifications(:replies)

    assert_equal 2, entries.length
    assert_equal 2, requests.length
    assert_equal [], replies

    mock("#{RUN_PATH}/interaction", :accept => "application/atom+xml",
      :credentials => $userinfo,
      :output => "get-rest-run-interaction-feed-2.raw")

    # No new requests...
    assert_equal [], @run.notifications

    # Refresh local lists.
    entries = @run.notifications(:all)
    requests = @run.notifications(:requests)
    replies = @run.notifications(:replies)

    # One more entry in total.
    assert_equal 3, entries.length

    # Should not lose a request.
    assert_equal 2, requests.length

    # Should gain a reply.
    assert_equal 1, replies.length

    # One request should have a reply.
    assert requests[0].has_reply?
    refute requests[1].has_reply?

    refute replies[0].is_notification?
    refute replies[0].has_reply?
    assert replies[0].is_reply?
    assert_equal requests[0].id, replies[0].reply_to
    assert_equal "", replies[0].input_data
  end

end
