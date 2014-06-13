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

require 't2-server'

require 'helpers/fake-run'

class TestXMLMessages < Test::Unit::TestCase

  SINGLE_INPUT_XML = LibXML::XML::Document.string(
    '<port:input xmlns:port="http://ns.taverna.org.uk/2010/port/" xmlns:xlink="http://www.w3.org/1999/xlink" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/input/expected/input/IN" port:name="IN" port:depth="0"/>'
  ).root

  LIST_INPUT_XML = LibXML::XML::Document.string(
    '<port:input xmlns:port="http://ns.taverna.org.uk/2010/port/" xmlns:xlink="http://www.w3.org/1999/xlink" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/input/expected/input/IN" port:name="IN" port:depth="1"/>'
  ).root

  SINGLE_OUTPUT_XML = LibXML::XML::Document.string(
    '<port:output xmlns:port="http://ns.taverna.org.uk/2010/port/" xmlns:xlink="http://www.w3.org/1999/xlink" port:name="OUT" port:depth="0">'\
      '<port:value port:contentFile="/out/OUT" port:contentType="text/plain" port:contentByteLength="5" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/wd/out/OUT"/>'\
    '</port:output>'
  ).root

  LIST_OUTPUT_XML = LibXML::XML::Document.string(
    '<port:output xmlns:port="http://ns.taverna.org.uk/2010/port/" xmlns:xlink="http://www.w3.org/1999/xlink" port:name="OUT" port:depth="1">'\
      '<port:list port:length="3" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/wd/out/OUT">'\
        '<port:value port:contentFile="/out/OUT/1" port:contentType="text/plain" port:contentByteLength="7" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/wd/out/OUT/1"/>'\
        '<port:error port:errorFile="/out/OUT/2.error" port:errorByteLength="101" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/wd/out/OUT/2.error"/>'\
        '<port:absent/>'\
      '</port:list>'\
    '</port:output>'
  ).root

  def test_singleton_input_port
    run = FakeRun.new
    port = T2Server::InputPort.new(run, SINGLE_INPUT_XML)

    assert_equal "IN", port.name
    assert_equal 0, port.depth

    refute port.remote_file?
    refute port.file?
    assert_nil port.value
    refute port.set?
  end

  def test_list_input_port
    run = FakeRun.new
    port = T2Server::InputPort.new(run, LIST_INPUT_XML)

    assert_equal "IN", port.name
    assert_equal 1, port.depth

    refute port.remote_file?
    refute port.file?
    assert_nil port.value
    refute port.set?
  end

  def test_set_input_port_value
    value = "test"
    run = FakeRun.new
    port = T2Server::InputPort.new(run, SINGLE_INPUT_XML)
    port.value = value

    assert port.set?
    refute port.file?
    refute port.remote_file?
    assert_equal value, port.value
  end

  def test_set_input_port_file
    filename = "/test/filename.txt"
    run = FakeRun.new
    port = T2Server::InputPort.new(run, SINGLE_INPUT_XML)
    port.file = filename

    assert port.set?
    assert port.file?
    refute port.remote_file?
    assert_equal filename, port.file
  end

  def test_set_input_port_remote_file
    filename = "/test/filename.txt"
    run = FakeRun.new
    port = T2Server::InputPort.new(run, SINGLE_INPUT_XML)
    port.remote_file = filename

    assert port.set?
    assert port.file?
    assert port.remote_file?
    assert_equal filename, port.file
  end

  def test_set_and_reset_input_port
    value = "test"
    filename = "/test/filename.txt"
    run = FakeRun.new
    port = T2Server::InputPort.new(run, SINGLE_INPUT_XML)

    # Value
    port.value = value
    assert port.set?
    refute port.file?
    refute port.remote_file?
    assert_equal value, port.value

    # Local file
    port.file = filename
    assert port.set?
    assert port.file?
    refute port.remote_file?
    assert_equal filename, port.file

    # Remote file
    port.remote_file = filename
    assert port.set?
    assert port.file?
    assert port.remote_file?
    assert_equal filename, port.file

    # And back to a value
    port.value = value
    assert port.set?
    refute port.file?
    refute port.remote_file?
    assert_equal value, port.value
  end

  def test_set_input_port_list
    delimiter = "!"
    list = [1, "two", :three]
    list_join = list.join(delimiter)
    run = FakeRun.new
    port = T2Server::InputPort.new(run, LIST_INPUT_XML)
    port.value = list
    port.delimiter = delimiter

    assert port.set?
    refute port.file?
    refute port.remote_file?
    assert_equal list, port.value
    assert_equal list_join, port.value(true)
  end

  def test_singleton_output_port
    port = T2Server::OutputPort.new(nil, SINGLE_OUTPUT_XML)

    refute port.empty?
    refute port.error?
    assert_equal "OUT", port.name
    assert_equal 0, port.depth
    assert_equal "text/plain", port.type
    assert_equal 5, port.size
    assert_equal 5, port.total_size
    assert port.reference.instance_of?(URI::HTTPS)
  end

  def test_list_output_port
    sizes = [7, 101, 0]
    types = ["text/plain", "application/x-error", "application/x-empty"]

    port = T2Server::OutputPort.new(nil, LIST_OUTPUT_XML)

    refute port.empty?
    assert port.error?
    assert_equal "OUT", port.name
    assert_equal 1, port.depth
    assert_equal 108, port.total_size

    assert_equal sizes, port.size
    assert_equal types, port.type

    assert_equal 3, port.size.length

    refute port[0].empty?
    refute port[0].error?
    assert_equal types[0], port[0].type
    assert_equal sizes[0], port[0].size
    assert port[0].reference.instance_of?(URI::HTTPS)

    refute port[1].empty?
    assert port[1].error?
    assert_equal types[1], port[1].type
    assert_equal sizes[1], port[1].size
    assert port[1].reference.instance_of?(URI::HTTPS)

    assert port[2].empty?
    refute port[2].error?
    assert_equal types[2], port[2].type
    assert_equal sizes[2], port[2].size
    assert port[2].reference.instance_of?(URI::Generic)
  end

end
