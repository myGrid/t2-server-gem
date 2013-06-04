# Copyright (c) 2010-2013 The University of Manchester, UK.
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

require 'optparse'
require 't2-server'

module T2Server
  module CLI
    @opts = nil

    # set up common options and return creds if provided
    def register_options(banner)
      user = nil
      pass = ""
      conn_params = DefaultConnectionParameters.new

      @opts = OptionParser.new do |opt|
        opt.banner = banner
        if block_given?
          yield opt
        end

        # SSL options
        opt.on("-E CERT_FILE:PASSWORD", "--cert=CERT_FILE:PASSWORD", "Use " +
          "the specified certificate file for client authentication. If the " +
          "optional password is not provided it will be asked for on the " +
          "command line. Must be in PEM format.") do |val|
            cert, cpass = val.chomp.split(":", 2)
            conn_params[:client_certificate] = cert
            conn_params[:client_password] = cpass if cpass
        end
        opt.on("--cacert=CERT_FILE", "Use the specified certificate file to " +
          "verify the peer. Must be in PEM format.") do |val|
            conn_params[:ca_file] = val.chomp
        end
        opt.on("--capath=CERTS_PATH", "Use the specified certificate " +
          "directory to verify the peer. Certificates must be in PEM " +
          "format") do |val|
            conn_params[:ca_path] = val.chomp
        end
        opt.on("-k", "--insecure", "Allow insecure connections: no peer " +
          "verification.") do
            conn_params[:verify_peer] = false
        end
        opt.on("-1", "--tlsv1", "Use TLS version 1 when negotiating with " +
          "the remote Taverna Server server.") do
            conn_params[:ssl_version] = :TLSv1
        end
        opt.on("-2", "--sslv2", "Use SSL version 2 when negotiating with " +
          "the remote Taverna Server server.") do
            conn_params[:ssl_version] = :SSLv23
        end
        opt.on("-3", "--sslv3", "Use SSL version 3 when negotiating with " +
          "the remote Taverna Server server.") do
            conn_params[:ssl_version] = :SSLv3
        end

        # common options
        opt.on_tail("-u", "--username=USERNAME", "The username to use for " +
          "server operations.") do |val|
            user = val.chomp
        end
        opt.on_tail("-p", "--password=PASSWORD", "The password to use for " +
          "the supplied username.") do |val|
            pass = val.chomp
        end
        opt.on_tail("-h", "-?", "--help", "Show this help message.") do
          puts opt
          exit
        end
        opt.on_tail("-v", "--version", "Show the version.") do
          puts "Taverna 2 Server Ruby Gem version: #{T2Server::Version::STRING}"
          exit
        end
      end

      # parse options
      @opts.parse!

      creds = user.nil? ? nil : HttpBasic.new(user, pass)
      [conn_params, creds]
    end

    # separate the creds if they are supplied in the uri
    def parse_address(address, creds)
      if address == nil || address == ""
        puts @opts
        exit 1
      end

      p_uri, p_creds = Util.strip_uri_credentials(address)
      creds != nil ? [p_uri, creds] : [p_uri, p_creds]
    end

    def opts
      @opts
    end
  end
end
