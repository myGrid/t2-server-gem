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

require 'forwardable'

module T2Server

  # This is the base class for holding parameters for network connections. It
  # delegates most work to the underlying Hash in which options are actually
  # stored.
  #
  # The parameters that can be set are:
  # * :ca_file
  # * :ca_path
  # * :verify_peer
  # * :client_certificate
  # * :client_password
  # * :ssl_version
  # All others will be ignored. Any parameters not set will return +nil+ when
  # queried.
  class ConnectionParameters
    # :stopdoc:
    ALLOWED_PARAMS = [
      :ca_file,
      :ca_path,
      :verify_peer,
      :client_certificate,
      :client_password,
      :ssl_version
    ]
    # :startdoc:

    extend Forwardable
    def_delegators :@params, :[], :to_s, :inspect

    # Create a new set of connection parameters with no defaults set.
    def initialize
      @params = {}
    end

    # :call-seq:
    #   [param] = value -> value
    #
    # Set a connection parameter. See the list of allowed parameters in the
    # class description.
    def []=(param, value)
      @params[param] = value if ALLOWED_PARAMS.include?(param)
    end
  end

  # Connection parameters with sensible defaults set for standard connections.
  # If the connection is over SSL then the peer will be verified using the
  # underlying OS's certificate store.
  class DefaultConnectionParameters < ConnectionParameters
    # Create connection parameters that are secure by default and verify the
    # server that is being connected to.
    def initialize
      super
      self[:verify_peer] = true
    end
  end

  # Connection parameters that specifically turn off peer verification when
  # using SSL.
  class InsecureSSLConnectionParameters < ConnectionParameters
    # Create connection parameters that are insecure by default and do not
    # verify the server that is connected to.
    def initialize
      super
      self[:verify_peer] = false
    end
  end

  # Connection parameters that simplify setting up verification of servers with
  # "self-signed" or non-standard certificates.
  class CustomCASSLConnectionParameters < DefaultConnectionParameters
    # :call-seq:
    #   new(path) -> CustomCASSLConnectionParameters
    #
    # _path_ can either be a directory where the required certificate is stored
    # or the path to the certificate file itself.
    def initialize(path)
      super

      case path
      when String
        self[:ca_path] = path if File.directory? path
        self[:ca_file] = path if File.file? path
      when File
        self[:ca_file] = path.path
      when Dir
        self[:ca_path] = path.path
      end
    end
  end

  # Connection parameters that simplify setting up client authentication to a
  # server over SSL.
  class ClientAuthSSLConnectionParameters < DefaultConnectionParameters
    # :call-seq:
    #   new(certificate, password = nil) -> ClientAuthSSLConnectionParameters
    #
    # _certificate_ should point to a file with the client user's certificate
    # and private key. The key will be unlocked with _password_ if it is
    # encrypted. If _password_ is not specified, but needed, then the
    # underlying SSL implementation may ask for it if it can.
    def initialize(cert, password = nil)
      super

      case cert
      when String
        self[:client_certificate] = cert
      when File
        self[:client_certificate] = cert.path
      end

      self[:client_password] = password
    end
  end
end
