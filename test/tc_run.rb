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

require 'helpers/mangle-time'
require 'helpers/test-cache'

class TestRun < Test::Unit::TestCase
  include T2Server::Mocks

  WKF_PASS = "test/workflows/pass_through.t2flow"

  # Some expiry times, mangled to work in different timezones.
  TIME_OBJ = Time.now                                      # Ruby time object
  TIME_STR = TIME_OBJ.strftime("%Y-%m-%d %H:%M:%S.%2N %z") # Ruby time string
  TIME_RET = TIME_OBJ.xmlschema(2)                         # Server return format
  TIME_SET = mangle_time(TIME_OBJ)                         # Server update format

  # Need to lock down the run UUID so recorded server responses make sense.
  RUN_UUID = "a341b87f-25cc-4dfd-be36-f5b073a6ba74"
  RUN_PATH = "/rest/runs/#{RUN_UUID}"
  RUN_LSTN = "#{RUN_PATH}/listeners/io/properties"

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

  # Test run connection
  def test_run_create_and_delete
    status = mock("#{RUN_PATH}/status", :accept => "text/plain",
      :credentials => $userinfo, :body => "Finished")
    del = mock(RUN_PATH, :method => :delete, :status => [204, 404, 404],
      :credentials => $userinfo)

    assert @run.finished?
    refute @run.deleted?

    assert @run.delete
    assert @run.deleted?
    refute @run.finished?
    assert_nothing_raised(T2Server::AttributeNotFoundError) do
      assert @run.delete # Should still return true, not raise 404
    end
    assert @run.delete # Should still return true

    assert_equal :deleted, @run.status
    assert_not_equal :finished, @run.status

    assert_requested status, :times => 1
    assert_requested del, :times => 3
  end

  # Test run naming.
  def test_run_naming
    mock("#{RUN_PATH}/name", :accept => "text/plain", :status => 200,
      :credentials => $userinfo, :output => "get-rest-run-name.raw")

    # Read initial name.
    assert @run.name.length > 0
    assert_equal "Workflow1", @run.name

    # Set a new name.
    name = "No input or output"

    mock("#{RUN_PATH}/name", :method => :put, :body => name,
      :status => 200, :credentials => $userinfo)

    assert @run.name = name

    # Set a name that is too long. The mock should only see the first 48
    # characters.
    long_name = "0123456789012345678901234567890123456789ABCDEFGHIJ"

    mock("#{RUN_PATH}/name", :method => :put, :body => long_name[0...48],
      :status => 200, :credentials => $userinfo)

    assert @run.name = long_name
  end

  def test_get_expiry
    mock("#{RUN_PATH}/expiry", :accept => "text/plain", :body => TIME_RET,
      :status => 200, :credentials => $userinfo)

    exp = @run.expiry
    assert exp.instance_of?(Time)
  end

  def test_update_expiry
    exp = mock("#{RUN_PATH}/expiry", :method => :put, :accept => "*/*",
      :status => 200, :body => TIME_SET, :credentials => $userinfo)

    @run.expiry = TIME_STR
    @run.expiry = TIME_OBJ

    assert_requested exp, :times => 2
  end

  # Upload workflow as a string, then test getting it back.
  def test_get_workflow
    workflow = File.read(WKF_PASS)

    wkf = mock("#{RUN_PATH}/workflow", :body => workflow,
      :accept => "application/xml", :credentials => $userinfo)

    # Download twice to check it's only actually retrieved once.
    assert_equal workflow, @run.workflow
    assert_equal workflow, @run.workflow

    assert_requested wkf, :times => 1
  end

  def test_mkdir
    dir = "test"
    location = "#{RUN_PATH}/wd/#{dir}"
    mock("#{RUN_PATH}/wd", :method => :post, :accept => "*/*", :status => 201,
      :credentials => $userinfo, :location => location)

    assert @run.mkdir(dir)
  end

  def test_listeners
    mock("#{RUN_LSTN}/exitcode", :accept => "text/plain", :body => "0",
      :credentials => $userinfo)
    mock("#{RUN_LSTN}/stdout", :accept => "text/plain", :body => "Out",
      :credentials => $userinfo)
    mock("#{RUN_LSTN}/stderr", :accept => "text/plain", :body => "Error",
      :credentials => $userinfo)

    # Check the exitcode is parsed into a number and other things not mangled.
    exit = @run.exitcode
    assert_equal 0, exit
    assert_instance_of(Fixnum, exit)
    assert_equal "Out", @run.stdout
    assert_equal "Error", @run.stderr
  end

  def test_full_run
    data = "Hello"

    in_exp = mock("#{RUN_PATH}/input/expected", :accept => "application/xml",
      :credentials => $userinfo, :output => "get-rest-run-input-expected.raw")
    mock("#{RUN_PATH}/input/input/IN", :method => :put, :accept => "*/*",
      :status => 200, :credentials => $userinfo)
    mock("#{RUN_PATH}/status", :method => :put, :body => "Operating",
      :status => 200, :credentials => $userinfo)

    # Re-mock status to fake up a running run.
    status = mock("#{RUN_PATH}/status", :accept => "text/plain",
      :status => 200, :credentials => $userinfo,
      :body => ["Initialized", "Initialized", "Operating", "Operating",
        "Operating", "Finished"])

    out = mock("#{RUN_PATH}/output", :accept => "application/xml",
      :credentials => $userinfo, :output => "get-rest-run-output.raw")
    mock("#{RUN_PATH}/wd/out/OUT", :accept => "application/octet-stream",
      :status => 200, :credentials => $userinfo, :body => data)

    assert_nothing_raised(T2Server::AttributeNotFoundError) do
      @run.input_port("IN").value = data
    end
    assert_equal data, @run.input_port("IN").value

    # Need to start the run to trigger input upload, then don't wait between
    # mocked polling of status.
    @run.start

    assert @run.running?

    @run.wait(0)

    assert @run.finished?

    outputs = @run.output_ports
    assert_equal 1, outputs.length

    assert_equal data, @run.output_port("OUT").value

    # No network access should occur on the next call.
    assert_nothing_raised(WebMock::NetConnectNotAllowedError) do
      assert_nil @run.output_port("wrong!")
    end

    assert_requested status, :times => 6
    assert_requested in_exp, :times => 1
    assert_requested out, :times => 1
  end

  def test_output_no_errors
    status = mock("#{RUN_PATH}/status", :accept => "text/plain",
      :status => 200, :credentials => $userinfo,
      :body => ["Operating", "Finished"])
    out = mock("#{RUN_PATH}/output", :accept => "application/xml",
      :credentials => $userinfo, :output => "get-rest-run-output.raw")

    # Status :running
    refute @run.error?

    # Status :finished
    refute @run.error?

    assert_requested status, :times => 2
    assert_requested out, :times => 1
  end

  def test_output_with_errors
    status = mock("#{RUN_PATH}/status", :accept => "text/plain",
      :status => 200, :credentials => $userinfo,
      :body => ["Operating", "Finished"])
    out = mock("#{RUN_PATH}/output", :accept => "application/xml",
      :credentials => $userinfo,
      :output => "get-rest-run-output-list-errors.raw")

    # Status :running
    refute @run.error?

    # Status :finished
    assert @run.error?

    assert_requested status, :times => 2
    assert_requested out, :times => 1
  end

  def test_getting_output
    mock("#{RUN_PATH}/status", :accept => "text/plain", :status => 200,
      :credentials => $userinfo, :body => "Finished")
    out = mock("#{RUN_PATH}/output", :accept => "application/xml",
      :credentials => $userinfo, :output => "get-rest-run-output.raw")
    mock("#{RUN_PATH}/wd/out/OUT", :accept => "application/octet-stream",
      :status => 200, :credentials => $userinfo,
      :body => mocked_file("log.txt"))

    data = File.read("test/mocked-server-responses/log.txt")

    assert_equal data, @run.output_port("OUT").value

    out_stream = TestCache.new
    assert_equal data.length, @run.output_port("OUT").stream_value(out_stream)
    assert_equal data, out_stream.data

    out_stream = ""
    @run.output_port("OUT").value do |chunk|
      out_stream += chunk
    end
    assert_equal data, out_stream

    assert_requested out, :times => 1
  end

  def test_output_range
    range = 5..30
    data = File.read("test/mocked-server-responses/log.txt")[range]

    mock("#{RUN_PATH}/status", :accept => "text/plain", :status => 200,
      :credentials => $userinfo, :body => "Finished")
    out = mock("#{RUN_PATH}/output", :accept => "application/xml",
      :credentials => $userinfo, :output => "get-rest-run-output.raw")
    mock("#{RUN_PATH}/wd/out/OUT", :accept => "application/octet-stream",
      :status => 206, :credentials => $userinfo, :body => data)

    assert_equal data, @run.output_port("OUT").value(range)

    out_stream = ""
    @run.output_port("OUT").value(range) do |chunk|
      out_stream += chunk
    end
    assert_equal data, out_stream

    assert_requested out, :times => 1
  end

  def test_output_list
    output_0_ref = "wd/out/OUT/1"
    output_0_value = "String0"
    output_4_ref = "wd/out/OUT/5.error"
    output_4_value = "Processor 'Sometimes_Fails' - Port 'out': Line 6: java.lang.RuntimeException: Fails every four runs!\n"
    status = mock("#{RUN_PATH}/status", :accept => "text/plain",
      :status => 200, :credentials => $userinfo, :body => "Finished")
    out = mock("#{RUN_PATH}/output", :accept => "application/xml",
      :credentials => $userinfo,
      :output => "get-rest-run-output-list-errors.raw")
    out_0 = mock("#{RUN_PATH}/#{output_0_ref}", :status => 200,
      :accept => "application/octet-stream", :credentials => $userinfo,
      :body => output_0_value)
    out_4 = mock("#{RUN_PATH}/#{output_4_ref}", :status => 200,
      :accept => "application/octet-stream", :credentials => $userinfo,
      :body => output_4_value)

    output = @run.output_port("OUT")

    assert_equal 1, output.depth
    assert_equal 40, output.size.length
    assert_equal 40, output.type.length
    assert_equal 40, output.reference.length

    assert_equal output_0_value.size, output[0].size
    assert_equal "text/plain", output[0].type
    assert_equal "https://localhost/taverna#{RUN_PATH}/#{output_0_ref}",
      output[0].reference.to_s
    assert_equal output_0_value, output[0].value

    output_0_stream = TestCache.new
    assert_equal output_0_value.size, output[0].stream_value(output_0_stream)
    assert_equal output_0_value, output_0_stream.data

    assert_equal output_4_value.size, output[4].size
    assert_equal "application/x-error", output[4].type
    assert_equal "https://localhost/taverna#{RUN_PATH}/#{output_4_ref}",
      output[4].reference.to_s
    assert_equal output_4_value, output[4].value

    output_4_stream = TestCache.new
    assert_equal output_4_value.size, output[4].stream_value(output_4_stream)
    assert_equal output_4_value, output_4_stream.data

    assert_requested status, :times => 1
    assert_requested out, :times => 1
  end

  def test_log
    log = mock("#{RUN_PATH}/wd/logs/detail.log", :accept => "text/plain",
      :status => 200, :credentials => $userinfo,
      :body => mocked_file("log.txt"))

    # Should be an error if a parameter and a block are passed in here.
    assert_raise(ArgumentError) do
      @run.log("log.txt") do |chunk|
        # ...
      end
    end

    assert_nothing_raised(ArgumentError) do
      log_str = @run.log

      assert_not_equal(log_str, "")

      log_stream = ""
      @run.log do |chunk|
        log_stream += chunk
      end
      assert_equal log_str, log_stream

      log_cache = TestCache.new
      @run.log(log_cache)
      assert_not_equal 0, log_cache.size
      assert_equal log_str, log_cache.data
    end

    assert_requested log, :times => 3
  end

  def test_create_start_finish_times
    %w(create start finish).each do |time|
      mock("#{RUN_PATH}/#{time}Time", :accept => "text/plain", :body => TIME_RET,
        :credentials => $userinfo)

      t = @run.send("#{time}_time".to_sym)
      assert t.instance_of?(Time)
      assert TIME_STR, t.to_s
    end
  end

  def test_bad_state
    # Re-mock status to fake up an already running run.
    status = mock("#{RUN_PATH}/status", :accept => "text/plain",
      :status => 200, :credentials => $userinfo, :body => "Operating")

    assert_raise(T2Server::RunStateError) do
      @run.start
    end
  end

  def test_upload_file
    filename = "in.txt"
    mock("#{RUN_PATH}/wd/#{filename}", :method => :put, :accept => "*/*",
      :status => 201, :credentials => $userinfo,
      :location => "https://localhost/taverna#{RUN_PATH}/wd/#{filename}")

    file = @run.upload_file("test/workflows/#{filename}")

    assert_equal filename, file
  end

  def test_upload_data
    filename = "in.txt"
    location = "https://localhost/taverna#{RUN_PATH}/wd/#{filename}"
    data = File.new("test/workflows/#{filename}")

    mock("#{RUN_PATH}/wd/#{filename}", :method => :put, :accept => "*/*",
      :status => 201, :credentials => $userinfo, :location => location)

    file = @run.upload_data(data, filename)

    assert_equal location, file.to_s
  end

end
