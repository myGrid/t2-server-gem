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

class TestXML
  include T2Server::XML::Methods
end

class TestXMLMessages < Test::Unit::TestCase

  def setup
    @test = TestXML.new
  end

  def test_mkdir_fragment
    dir_name = "new_dir"
    fragment = @test.xml_mkdir_fragment(dir_name)
    assert fragment.instance_of?(String)

    doc = LibXML::XML::Document.string(fragment)
    root = doc.root
    check_namespaces(root)

    assert_equal "mkdir", root.name
    assert_equal [], root.children
    assert_equal "", root.content

    assert root.attributes?
    assert_equal dir_name, root["name"]
  end

  private

  def check_namespaces(node)
    namespaces = node.namespaces
    assert_nil namespaces.default

    ns_list = namespaces.definitions
    assert_equal 4, ns_list.count

    ns_list.each do |ns|
      assert T2Server::XML::Namespaces::MAP.has_key?(ns.prefix)
      assert T2Server::XML::Namespaces::MAP.has_value?(ns.href)
    end
  end

end
