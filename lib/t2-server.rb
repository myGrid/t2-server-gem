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

require 'yaml'
require 't2-server/xml/xml'
require 't2-server/exceptions'
require 't2-server/credentials'
require 't2-server/connection'
require 't2-server/connection-parameters'
require 't2-server/port'
require 't2-server/server'
require 't2-server/run'
require 't2-server/admin'

# This is a Ruby library to interface with the Taverna 2 Server REST API.
#
# There are two API entry points:
# * T2Server::Run - Use this for running single jobs on a server.
# * T2Server::Server - Use this if you are providing a web interface to a
#   Taverna 2 Server instance.
module T2Server
  module Version
    # Version information in a Hash
    INFO = YAML.load_file(File.join(File.dirname(__FILE__), "..", "version.yml"))

    # Version number as a String
    STRING = [:major, :minor, :patch].map {|d| INFO[d]}.compact.join('.')
  end
end

# Add methods to the String class to operate on file paths.
class String
  # :call-seq:
  #   str.strip_path -> string
  #
  # Returns a new String with one leading and one trailing slash
  # removed from the ends of _str_ (if present).
  def strip_path
    self.gsub(/^\//, "").chomp("/")
  end

  # :call-seq:
  #   str.strip_path! -> str or nil
  #
  # Modifies _str_ in place as described for String#strip_path,
  # returning _str_, or returning +nil+ if no modifications were made. 
  def strip_path!
    g = self.gsub!(/^\//, "")
    self.chomp!("/") || g
  end
end

# Add a method to the URI class to strip user credentials from an address.
module URI
  
  # :call-seq:
  #   URI.strip_credentials(uri) -> URI, Credentials
  #
  # Strip user credentials from an address in URI or String format and return
  # a tuple of the URI minus the credentials and a T2Server::Credentials
  # object.
  def self.strip_credentials(uri)
    # we want to use URIs here but strings can be passed in
    unless uri.is_a? URI
      uri = URI.parse(uri.strip_path)
    end

    creds = nil

    # strip username and password from the URI if present
    if uri.user != nil
      creds = T2Server::HttpBasic.new(uri.user, uri.password)

      uri = URI::HTTP.new(uri.scheme, nil, uri.host, uri.port, nil,
      uri.path, nil, nil, nil);
    end

    [uri, creds]
  end
end
