# Copyright (c) 2010, 2011 The University of Manchester, UK.
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
require 'libxml'

module T2Server
  # :stopdoc:
  module XML

    # Shut the libxml error handler up
    LibXML::XML::Error.set_handler(&LibXML::XML::Error::QUIET_HANDLER)

    module Namespaces
      SERVER = "http://ns.taverna.org.uk/2010/xml/server/"
      REST   = SERVER + "rest/"
      ADMIN  = SERVER + "admin/"
      PORT   = "http://ns.taverna.org.uk/2010/port/"

      MAP    = {
        "nss"  => Namespaces::SERVER,
        "nsr"  => Namespaces::REST,
        "nsa"  => Namespaces::ADMIN,
        "port" => Namespaces::PORT
      }
    end

    module Fragments
      WORKFLOW      = "<t2s:workflow xmlns:t2s=\"#{Namespaces::SERVER}\">\n  %s\n</t2s:workflow>"
      RUNINPUT      = "<t2sr:runInput xmlns:t2sr=\"#{Namespaces::REST}\">\n  %s\n</t2sr:runInput>"
      RUNINPUTVALUE = RUNINPUT % "<t2sr:value>%s</t2sr:value>"
      RUNINPUTFILE  = RUNINPUT % "<t2sr:file>%s</t2sr:file>"
      UPLOAD        = "<t2sr:upload xmlns:t2sr=\"#{Namespaces::REST}\" t2sr:name=\"%s\">\n  %s\n</t2sr:upload>"
      MKDIR         = "<t2sr:mkdir xmlns:t2sr=\"#{Namespaces::REST}\" t2sr:name=\"%s\" />"
    end

    module Methods
      def xml_document(string)
        LibXML::XML::Document.string(string)
      end

      def xml_text_node(text)
        LibXML::XML::Node.new_text(text)
      end

      def xml_children(doc, &block)
        doc.each { |node| yield node }
      end

      # This method needs to be declared as a module method so
      # it can be used as a class method when it is mixed in.
      def xpath_compile(xpath)
        LibXML::XML::XPath::Expression.new(xpath)
      end
      module_function :xpath_compile

      def xpath_find(doc, expr)
        doc.find(expr, Namespaces::MAP)
      end

      def xpath_first(doc, expr)
        doc.find_first(expr, Namespaces::MAP)
      end

      def xpath_attr(doc, expr, attribute)
        doc.find_first(expr, Namespaces::MAP).attributes[attribute]
      end
    end
  end
  # :startdoc:
end
