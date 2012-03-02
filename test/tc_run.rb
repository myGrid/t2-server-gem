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

class TestRun < Test::Unit::TestCase

  # Test run connection
  def test_run_misc
    assert_nothing_raised(T2Server::ConnectionError) do
      T2Server::Run.create($uri, $wkf_pass, $creds, $conn_params)
    end
  end

  # Test misc run functions
  def test_status_codes
    T2Server::Run.create($uri, $wkf_pass, $creds, $conn_params) do |run|

      # test mkdir
      assert(run.mkdir("test"))

      # set input, start, check state and wait
      assert_nothing_raised(T2Server::AttributeNotFoundError) do
        run.set_input("IN", "Hello, World!")
      end

      # test correct/incorrect status codes
      assert_equal(run.status, :initialized)
      assert_raise(T2Server::RunStateError) { run.wait }
      assert_nothing_raised(T2Server::RunStateError) { run.start }
      assert(run.running?)
      assert_equal(run.status, :running)
      assert_nothing_raised(T2Server::RunStateError) { run.wait }
      assert_equal(run.status, :finished)
      assert_raise(T2Server::RunStateError) { run.start }

      # exitcode and output
      assert_instance_of(Fixnum, run.exitcode)
      assert_equal(run.output_port("OUT").values, "Hello, World!")
      assert_equal(run.output_port("wrong!"), nil)

      # get zip file
      assert_nothing_raised(T2Server::T2ServerError) do
        assert_not_equal(run.zip_output, "")
      end

      # deletion
      assert(run.delete)
    end
  end

  # Test run with xml input
  def test_run_xml_input
    T2Server::Run.create($uri, $wkf_xml, $creds, $conn_params) do |run|
      run.set_input("xml","<hello><yes>hello</yes><no>everybody</no><yes>world</yes></hello>")
      run.set_input("xpath","//yes")
      run.start
      run.wait
      assert_equal(run.output_port("nodes").values, ["hello", "world"])
    end
  end

  def test_run_file_input
    # run with file input
    T2Server::Run.create($uri, $wkf_pass, $creds, $conn_params) do |run|

      assert_nothing_raised(T2Server::AttributeNotFoundError) do
        run.upload_input_file("IN", $file_input)
      end

      run.start
      assert(run.running?)
      assert_nothing_raised(T2Server::RunStateError) { run.wait }
      assert_equal(run.output_port("OUT").values, "Hello, World!")
    end
  end

  # Test run that returns list of lists, some empty, using baclava for input
  def test_baclava_input
    T2Server::Run.create($uri, $wkf_lists, $creds, $conn_params) do |run|
      assert_nothing_raised(T2Server::AttributeNotFoundError) do
        run.baclava_input = $list_input
      end

      assert_equal(run.input_ports.keys.sort, ["MANY_IN", "SINGLE_IN"])
      assert_equal(run.input_port("MANY_IN").depth, 3)
      assert_equal(run.input_port("SINGLE_IN").depth, 1)
      assert(run.baclava_input?)
      assert(run.input_port("SINGLE_IN").baclava?)
      assert(run.input_port("SINGLE_IN").set?)

      run.start
      assert(run.running?)
      assert_nothing_raised(T2Server::RunStateError) { run.wait }
      assert_equal(run.output_ports.keys.sort, ["MANY", "SINGLE"])
      assert_equal(run.output_port("SINGLE").values, [])
      assert_equal(run.output_port("MANY").values,
        [[["boo"]], [["", "Hello"]], [], [[], ["test"], []]])
      assert_equal(run.output_port("MANY").total_size, 12)
      assert_equal(run.output_port("MANY")[1][0][1].value(1..3), "ell")
      assert_raise(NoMethodError) { run.output_port("SINGLE")[0].value }
    end
  end

  # Test run with baclava output
  def test_baclava_output
    T2Server::Run.create($uri, $wkf_pass, $creds, $conn_params) do |run|
      run.set_input("IN", "Some input...")
      assert_nothing_raised(T2Server::AttributeNotFoundError) do
        run.request_baclava_output
      end
      assert(run.baclava_output?)

      run.start
      assert(run.running?)
      assert_nothing_raised(T2Server::RunStateError) { run.wait }

      assert_nothing_raised(T2Server::AccessForbiddenError) do
        output = run.baclava_output
      end
    end
  end

  # Test partial result download
  def test_result_download
    T2Server::Run.create($uri, $wkf_pass, $creds, $conn_params) do |run|
      run.upload_input_file("IN", $file_strs)
      run.start
      run.wait

      # no data downloaded yet
      assert(run.output_port("OUT").value(:debug).nil?)

      # get just the first 10 bytes
      assert_equal(run.output_port("OUT").value(0...10),
        "123456789\n")

      # get a bad range - should return the first 10 bytes
      assert_equal(run.output_port("OUT").value(-10...10),
        "123456789\n")

      # confirm only the first 10 bytes have been downloaded
      assert_equal(run.output_port("OUT").value(:debug),
        "123456789\n")

      # ask for a separate 10 byte range
      assert_equal(run.output_port("OUT").value(20...30),
        "323456789\n")

      # confirm that enough was downloaded to connect the two ranges
      assert_equal(run.output_port("OUT").value(:debug),
        "123456789\n223456789\n323456789\n")

      # ask for a range that we already have
      assert_equal(run.output_port("OUT").value(5..25),
        "6789\n223456789\n323456")

      # confirm that no more has actually been downloaded
      assert_equal(run.output_port("OUT").value(:debug),
        "123456789\n223456789\n323456789\n")
    end
  end

  # test error handling
  def test_always_fail
    T2Server::Run.create($uri, $wkf_fail, $creds, $conn_params) do |run|
      run.start
      run.wait
      assert(run.output_port("OUT").value.nil?)
      assert(run.output_port("OUT").error?)
    end
  end
  
  def test_errors
    T2Server::Run.create($uri, $wkf_errors, $creds, $conn_params) do |run|
      run.start
      run.wait
      assert(run.output_port("OUT").error?)
    end
  end
end
