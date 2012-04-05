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

module T2Server
  module Util

    # :call-seq:
    #   Util.strip_uri_credentials(uri) -> URI, Credentials
    #
    # Strip user credentials from an address in URI or String format and return
    # a tuple of the URI minus the credentials and a T2Server::Credentials
    # object.
    def self.strip_uri_credentials(uri)
      # we want to use URIs here but strings can be passed in
      unless uri.is_a? URI
        uri = URI.parse(Util.strip_path_slashes(uri))
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

    # :call-seq:
    #   Util.strip_path_slashes(path) -> String
    #
    # Returns a new String with one leading and one trailing slash
    # removed from the ends of _path_ (if present).
    def self.strip_path_slashes(path)
      path.gsub(/^\//, "").chomp("/")
    end

  end
end
