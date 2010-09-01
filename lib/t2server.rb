# Copyright (c) 2010, The University of Manchester, UK.
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

require 't2server/xml'
require 't2server/exceptions'
require 't2server/server'
require 't2server/run'

# This is a Ruby library to interface with the Taverna 2 Server REST API.
#
# There are two API entry points:
# * T2Server::Run - Use this for running single jobs on a server.
# * T2Server::Server - Use this if you are providing a web interface to a
#   Taverna 2 Server instance.
module T2Server
  # The version of this library
  GEM_VERSION = "0.0.4"
  # The version of the Taverna 2 Server API that this library can interface with
  API_VERSION = "2.2a1"
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
