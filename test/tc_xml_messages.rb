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

require 'helpers/test-xml'

class TestXMLMessages < Test::Unit::TestCase

  def setup
    @test = TestXML.new
  end

  def test_mkdir_fragment
    dir_name = "new_dir"
    fragment = @test.xml_mkdir_fragment(dir_name)

    root = get_and_check_root(fragment, "mkdir")

    assert_equal [], root.children
    assert_equal "", root.content

    assert root.attributes?
    assert_equal dir_name, root["name"]
  end

  def test_upload_fragment
    file_name = "/file/name.txt"
    file_data = "test & data"
    fragment = @test.xml_upload_fragment(file_name, file_data)

    root = get_and_check_root(fragment, "upload")

    assert_equal file_data, root.content

    assert root.attributes?
    assert_equal file_name, root["name"]
  end

  def test_input_value_fragment
    input_value = "test & input"
    fragment = @test.xml_input_fragment(input_value)

    root = get_and_check_root(fragment, "runInput")

    refute root.attributes?

    check_child_nodes(root, "value" => input_value)
  end

  def test_input_file_fragment
    file_name = "/file/name.txt"
    fragment = @test.xml_input_fragment(file_name, :file)

    root = get_and_check_root(fragment, "runInput")

    refute root.attributes?

    check_child_nodes(root, "file" => file_name)
  end

  def test_trust_fragment
    cert_data = "test contents"
    cert_type = "X509"
    fragment = @test.xml_trust_fragment(cert_data, cert_type)

    root = get_and_check_root(fragment, "trustedIdentity")

    refute root.attributes?

    check_child_nodes(root, "certificateBytes" => cert_data,
      "fileType" => cert_type)
  end

  def test_permissions_fragment
    username = "taverna"
    permission = "destroy"
    fragment = @test.xml_permissions_fragment(username, permission)

    root = get_and_check_root(fragment, "permissionUpdate")

    refute root.attributes?

    check_child_nodes(root, "userName" => username,
      "permission" => permission)
  end

  def test_password_cred_fragment
    service = "http://example.com/service"
    username = "taverna"
    password = "T@v3rNa!"
    fragment = @test.xml_password_cred_fragment(service, username, password)

    root = get_and_check_root(fragment, "credential")

    refute root.attributes?

    check_child_nodes(root, "userpass" => {
      "serviceURI" => service,
      "username" => username,
      "password" => password
      }
    )
  end

  def test_keypair_cred_fragment
    service = "http://example.com/service"
    cred_name = "test_name"
    cred_bytes = "example cred"
    cred_type = "PKCS12"
    password = "T@v3rNa!"
    fragment = @test.xml_keypair_cred_fragment(service, cred_name, cred_bytes,
      cred_type, password)

    root = get_and_check_root(fragment, "credential")

    refute root.attributes?

    check_child_nodes(root, "keypair" => {
      "serviceURI" => service,
      "credentialName" => cred_name,
      "credentialBytes" => cred_bytes,
      "fileType" => cred_type,
      "unlockPassword" => password
      }
    )
  end

  private

  def check_child_nodes(node, children)
    names = children.keys
    num_children = 0

    node.each_element do |child|
      num_children += 1
      assert names.include?(child.name)
      if children[child.name].instance_of?(Hash)
        check_child_nodes(child, children[child.name])
      else
        assert_equal children[child.name], child.content
      end
    end

    assert_equal names.length, num_children
  end

  def get_and_check_root(fragment, root_name)
    assert fragment.instance_of?(String)

    doc = LibXML::XML::Document.string(fragment)
    root = doc.root
    assert_equal root_name, root.name
    check_namespaces(root)

    root
  end

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
