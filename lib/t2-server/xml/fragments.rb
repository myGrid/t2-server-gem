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

module T2Server
  module XML
    module Fragments
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
    end
  end
end
