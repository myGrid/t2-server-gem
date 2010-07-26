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

require 'net/http'

# The following code sets up a catch all exception to catch things that we
# can't do anything about ourselves, eg, timeouts and lost connections.
module T2Server
  module InternalHTTPError
  end

  # These are the HTTP errors we want to catch. Add the above exception as an
  # ancestor to them all.
  [
    EOFError,
    SocketError,
    Timeout::Error,
    Errno::EINVAL,
    Errno::ETIMEDOUT,
    Errno::ECONNRESET,
    Errno::ECONNREFUSED,
    Net::HTTPBadResponse,
    Net::HTTPHeaderSyntaxError,
    Net::ProtocolError
  ].each {|err| err.send(:include, InternalHTTPError)}

  # T2Server specific exceptions
  # Superclass just in case we want a catch all
  class T2ServerError < RuntimeError
  end

  class ConnectionError < T2ServerError
    attr_reader :cause
    def initialize(cause)
      @cause = cause
      super "Connection error (#{@cause.class.name}): #{@cause.message}"
    end
  end

  class UnexpectedServerResponse < T2ServerError
    def initialize(response)
      body = "\n#{response.body}" if response.body
      super "Unexpected server response: #{response.code}\n#{response.error!}#{body}"
    end
  end

  class RunNotFoundError < T2ServerError
    attr_reader :uuid
    def initialize(uuid)
      @uuid = uuid
      super "Could not find run #{@uuid}"
    end
  end

  class AttributeNotFoundError < T2ServerError
    attr_reader :path
    def initialize(path)
      @path = path
      super "Could not find attribute at #{@path}"
    end
  end

  class ServerAtCapacityError < T2ServerError
    attr_reader :limit
    def initialize(limit)
      @limit = limit
      super "The server is already running its configured limit of concurrent workflows (#{@limit})"
    end
  end

  class AccessForbiddenError < T2ServerError
    attr_reader :path
    def initialize(path)
      @path = path
      super "Access to #{@path} is forbidden. Either you do not have the required credentials or the server does not allow the requested operation"
    end
  end
end
