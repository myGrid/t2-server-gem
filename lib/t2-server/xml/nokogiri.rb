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

require 'rubygems'
require 'nokogiri'

module T2Server
  module XML

    module Methods
      def xml_document(string)
        Nokogiri::XML(string)
      end

      def xml_text_node(text)
        Nokogiri::XML::Text.new(text, Nokogiri::XML::Document.new).to_s
      end

      def xml_first_child(node)
        node.first_element_child
      end

      def xml_children(doc, &block)
        doc.children.each &block
      end

      def xml_node_name(node)
        node.node_name
      end

      def xml_node_content(node)
        node.content
      end

      def xml_node_attribute(node, attribute)
        node[attribute]
      end

      def xpath_compile(xpath)
        xpath
      end

      def xpath_find(doc, expr)
        doc.xpath(expr, Namespaces::MAP)
      end

      def xpath_first(doc, expr)
        doc.at_xpath(expr, Namespaces::MAP)
      end

      def xpath_attr(doc, expr, attribute)
        doc.at_xpath(expr, Namespaces::MAP)[attribute]
      end
    end
  end
end
