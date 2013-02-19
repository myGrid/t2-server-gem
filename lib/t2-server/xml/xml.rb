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

begin
  require 't2-server/xml/libxml'
rescue LoadError
  begin
    require 't2-server/xml/nokogiri'
  rescue LoadError
    require 't2-server/xml/rexml'
  end
end

module T2Server
  module XML

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
      WORKFLOW      = "<t2s:workflow xmlns:t2s=\"#{Namespaces::SERVER}\">\n"\
                        "  %s\n</t2s:workflow>"
      RUNINPUT      = "<t2sr:runInput xmlns:t2sr=\"#{Namespaces::REST}\">\n"\
                        "  %s\n</t2sr:runInput>"
      RUNINPUTVALUE = RUNINPUT % "<t2sr:value>%s</t2sr:value>"
      RUNINPUTFILE  = RUNINPUT % "<t2sr:file>%s</t2sr:file>"
      UPLOAD        = "<t2sr:upload xmlns:t2sr=\"#{Namespaces::REST}\" "\
                        "t2sr:name=\"%s\">\n  %s\n</t2sr:upload>"
      MKDIR         = "<t2sr:mkdir xmlns:t2sr=\"#{Namespaces::REST}\" "\
                        "t2sr:name=\"%s\" />"

      PERMISSION    = "<t2sr:userName>%s</t2sr:userName>"\
                      "<t2sr:permission>%s</t2sr:permission>"
      PERM_UPDATE   = "<t2sr:permissionUpdate "\
                        "xmlns:t2sr=\"#{Namespaces::REST}\">"\
                        "#{PERMISSION}</t2sr:permissionUpdate>"

      SERVICE_URI   = "<t2s:serviceURI>%s</t2s:serviceURI>"
      CREDENTIAL    = "<t2sr:credential xmlns:t2sr=\"#{Namespaces::REST}\""\
                        " xmlns:t2s=\"#{Namespaces::SERVER}\">\n"\
                        "%s\n</t2sr:credential>"
      USERPASS_CRED = "<t2s:userpass>\n"\
                        "  #{SERVICE_URI}\n"\
                        "  <t2s:username>%s</t2s:username>\n"\
                        "  <t2s:password>%s</t2s:password>\n"\
                        "</t2s:userpass>"

      KEYPAIR_CRED  = "<t2s:keypair>\n"\
                        "  #{SERVICE_URI}\n"\
                        "  <t2s:credentialName>%s</t2s:credentialName>\n"\
                        "  <t2s:credentialBytes>%s</t2s:credentialBytes>\n"\
                        "  <t2s:fileType>%s</t2s:fileType>\n"\
                        "  <t2s:unlockPassword>%s</t2s:unlockPassword>\n"\
                        "</t2s:keypair>"

      TRUST         = "<t2s:trustedIdentity "\
                        "xmlns:t2s=\"#{Namespaces::SERVER}\">\n"\
                        "  <t2s:certificateBytes>%s</t2s:certificateBytes>\n"\
                        "  <t2s:fileType>%s</t2s:fileType>\n"\
                        "</t2s:trustedIdentity>"
    end

    module Methods
      # The methods in this namespace are provided by the particular XML
      # library selected above. The xpath_compile method needs to be declared
      # as a module method so it can be used as a class method when it is
      # mixed in.
      module_function :xpath_compile
    end
  end
end
