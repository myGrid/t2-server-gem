# Copyright (c) 2010-2014 The University of Manchester, UK.
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

require 'libxml'

module T2Server
  module XML
    # Shut the libxml error handler up
    LibXML::XML::Error.set_handler(&LibXML::XML::Error::QUIET_HANDLER)

    module Methods
      def xml_document(string)
        LibXML::XML::Document.string(string)
      end

      def xml_first_child(node)
        node.first
      end

      def xml_children(doc, &block)
        doc.each { |node| yield node }
      end

      def xml_node_name(node)
        node.name
      end

      def xml_node_content(node)
        node.content
      end

      def xml_node_attribute(node, attribute)
        node.attributes[attribute]
      end

      def xpath_compile(xpath)
        LibXML::XML::XPath::Expression.new(xpath)
      end

      def xpath_find(doc, expr)
        doc.find(expr, Namespaces::MAP)
      end

      def xpath_first(doc, expr)
        doc.find_first(expr, Namespaces::MAP)
      end

      def xpath_attr(doc, expr, attribute)
        node = xpath_first(doc, expr)
        node.nil? ? nil : node.attributes[attribute]
      end

      # Given a list of xpath keys, extract the href URIs from those elements.
      def get_uris_from_doc(doc, keys)
        cache = XPathCache.instance
        uris = {}

        keys.each do |key|
          uri = xpath_attr(doc, cache[key], "href")
          uris[key] = uri.nil? ? nil : URI.parse(uri)
        end

        uris
      end

      def xml_input_fragment(port)
        if port.file?
          type = "file"
          value = port.file
        else
          type = "value"
          value = port.value.to_s
        end

        node = create_node("nsr:runInput", ["nsr:#{type}", value])
        create_document(node).to_s
      end

      def xml_mkdir_fragment(name)
        node = create_node("nsr:mkdir", { "nsr:name" => name })
        create_document(node).to_s
      end

      def xml_upload_fragment(name, data)
        node = create_node("nsr:upload", { "nsr:name" => name }, data)
        create_document(node).to_s
      end

      def xml_permissions_fragment(username, permission)
        node = create_node("nsr:permissionUpdate",
          ["nsr:userName", username], ["nsr:permission", permission])
        create_document(node).to_s
      end

      def xml_password_cred_fragment(uri, username, password)
        node = create_node("nsr:credential",
          ["nss:userpass",
            ["nss:serviceURI", uri],
            ["nss:username", username],
            ["nss:password", password]
          ]
        )

        create_document(node).to_s
      end

      def xml_keypair_cred_fragment(uri, name, key, type, password)
        node = create_node("nsr:credential",
          ["nss:keypair",
            ["nss:serviceURI", uri],
            ["nss:credentialName", name],
            ["nss:credentialBytes", key],
            ["nss:fileType", type],
            ["nss:unlockPassword", password]
          ]
        )

        create_document(node).to_s
      end

      def xml_trust_fragment(contents, type)
        node = create_node("nss:trustedIdentity",
          ["nss:certificateBytes", contents], ["nss:fileType", type])
        create_document(node).to_s
      end

      private

      def create_document(root)
        doc = LibXML::XML::Document.new
        doc.root = root

        Namespaces::MAP.each do |prefix, uri|
          LibXML::XML::Namespace.new(root, prefix, uri)
        end

        doc
      end

      def create_node(name, *rest)
        contents = nil
        attributes = {}
        children = []

        rest.each do |param|
          case param
          when Hash
            attributes = param
          when Array
            children.push(param)
          else
            contents = param
          end
        end

        node = LibXML::XML::Node.new(name, contents)

        attributes.each do |attr, value|
          LibXML::XML::Attr.new(node, attr, value)
        end

        children.each do |c|
          n = create_node(c.shift, *c)
          node << n
        end

        node
      end

    end
  end
end
