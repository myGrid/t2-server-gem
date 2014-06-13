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

# A fake run class that can be "initialized" and use "baclava" as needed.
class FakeRun
  def initialize(init = true, baclava = false)
    @init = init
    @baclava = baclava
  end

  def initialized?
    @init
  end

  def baclava_input?
    @baclava
  end
end

class TestXMLMessages < Test::Unit::TestCase

  SINGLE_INPUT_XML = LibXML::XML::Document.string(
    '<port:input xmlns:port="http://ns.taverna.org.uk/2010/port/" xmlns:xlink="http://www.w3.org/1999/xlink" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/input/expected/input/IN" port:name="IN" port:depth="0"/>'
  ).root

  SINGLE_OUTPUT_XML = LibXML::XML::Document.string(
    '<port:output xmlns:port="http://ns.taverna.org.uk/2010/port/" xmlns:xlink="http://www.w3.org/1999/xlink" port:name="OUT" port:depth="0">'\
      '<port:value port:contentFile="/out/OUT" port:contentType="text/plain" port:contentByteLength="5" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/wd/out/OUT"/>'\
    '</port:output>'
  ).root

  LIST_OUTPUT_XML = LibXML::XML::Document.string(
    '<port:output xmlns:port="http://ns.taverna.org.uk/2010/port/" xmlns:xlink="http://www.w3.org/1999/xlink" port:name="OUT" port:depth="1">'\
      '<port:list port:length="10" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/wd/out/OUT">'\
        '<port:value port:contentFile="/out/OUT/1" port:contentType="text/plain" port:contentByteLength="7" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/wd/out/OUT/1"/>'\
        '<port:value port:contentFile="/out/OUT/2" port:contentType="text/plain" port:contentByteLength="7" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/wd/out/OUT/2"/>'\
        '<port:value port:contentFile="/out/OUT/3" port:contentType="text/plain" port:contentByteLength="7" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/wd/out/OUT/3"/>'\
        '<port:value port:contentFile="/out/OUT/4" port:contentType="text/plain" port:contentByteLength="7" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/wd/out/OUT/4"/>'\
        '<port:error port:errorFile="/out/OUT/5.error" port:errorByteLength="101" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/wd/out/OUT/5.error"/>'\
        '<port:value port:contentFile="/out/OUT/6" port:contentType="text/plain" port:contentByteLength="7" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/wd/out/OUT/6"/>'\
        '<port:value port:contentFile="/out/OUT/7" port:contentType="text/plain" port:contentByteLength="7" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/wd/out/OUT/7"/>'\
        '<port:value port:contentFile="/out/OUT/8" port:contentType="text/plain" port:contentByteLength="7" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/wd/out/OUT/8"/>'\
        '<port:value port:contentFile="/out/OUT/9" port:contentType="text/plain" port:contentByteLength="7" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/wd/out/OUT/9"/>'\
        '<port:value port:contentFile="/out/OUT/10" port:contentType="text/plain" port:contentByteLength="7" xlink:href="https://localhost/taverna/rest/runs/a341b87f-25cc-4dfd-be36-f5b073a6ba74/wd/out/OUT/10"/>'\
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
    sizes = [7, 7, 7, 7, 101, 7, 7, 7, 7, 7]
    types = [
      "text/plain", "text/plain", "text/plain", "text/plain",
      "application/x-error", "text/plain", "text/plain", "text/plain",
      "text/plain", "text/plain"
    ]

    port = T2Server::OutputPort.new(nil, LIST_OUTPUT_XML)

    refute port.empty?
    assert port.error?
    assert_equal "OUT", port.name
    assert_equal 1, port.depth
    assert_equal 164, port.total_size

    assert_equal sizes, port.size
    assert_equal types, port.type

    10.times do |i|
      refute port[i].empty?
      assert_equal types[i] == "application/x-error", port[i].error?
      assert_equal types[i], port[i].type
      assert_equal sizes[i], port[i].size
      assert port[i].reference.instance_of?(URI::HTTPS)
    end
  end

end
