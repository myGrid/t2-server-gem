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

require 'net/http/persistent'

module T2Server
  # :stopdoc:
  # An internal module to collect all the exceptions that we
  # can't really do anything about ourselves, such as
  # timeouts and lost connections. This is further wrapped
  # and exposed in the API as T2Server::ConnectionError below.
  module InternalHTTPError
  end

  # These are the HTTP errors we want to catch. Add the above exception as an
  # ancestor to them all. Some are caught by Net::HTTP::Persistent and
  # re-raised as a Net::HTTP::Persistent::Error but keep them listed here just
  # in case.
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
    Net::ProtocolError,
    Net::HTTP::Persistent::Error
  ].each {|err| err.send(:include, InternalHTTPError)}

  # :startdoc:
  # This is a superclass for all T2Server exceptions. It is provided as a
  # useful catch-all for all the internally raised/thrown exceptions.
  class T2ServerError < RuntimeError
  end

  # Raised when there is an error with the connection to the server in some
  # way. This could be due to the server not accepting the connection, the
  # connection being dropped unexpectedly or a timeout of some sort.
  class ConnectionError < T2ServerError

    # The internal cause of this connection error.
    attr_reader :cause

    # Create a new ConnectionError with the specified cause. The cause to be
    # passed in should be the exception object that caused the connection
    # error.
    def initialize(cause)
      @cause = cause
      super "Connection error (#{@cause.class.name}): #{@cause.message}"
    end
  end

  # Raised when there is an unexpected response from the server. This does
  # not necessarily indicate a problem with the server.
  class UnexpectedServerResponse < T2ServerError

    # The method that was called to produce this error.
    attr_reader :method

    # The path of the URI that returned this error.
    attr_reader :path

    # The HTTP error code of this error.
    attr_reader :code

    # The response body of this error. If the server did not supply one then
    # this will be "<none>".
    attr_reader :body

    # Create a new UnexpectedServerResponse with details of which HTTP method
    # was called, the path that it was called on and the specified unexpected
    # response. The response to be passed in is that which was returned by a
    # call to Net::HTTP#request.
    def initialize(method, path, response)
      @method = method
      @path = path
      @code = response.code
      @body = response.body.to_s
      @body = @body.empty? ? "<none>" : "#{response.body}"
      message = "Unexpected server response:\n  Method: #{@method}\n  Path: "\
        "#{@path}\n  Code: #{@code}\n  Body: #{@body}"
      super message
    end
  end

  # Raised when the run that is being operated on cannot be found. If the
  # expectation is that the run exists then it could have been destroyed by
  # a timeout or another user.
  class RunNotFoundError < T2ServerError

    # The identifier of the run that was not found on the server.
    attr_reader :identifier

    # Create a new RunNotFoundError with the specified identifier.
    def initialize(id)
      @identifier = id
      super "Could not find run #{@identifier}"
    end
  end

  # Indicates that the attribute that the user is trying to read/change does
  # not exist. The attribute could be a server or run attribute.
  class AttributeNotFoundError < T2ServerError

    # The path of the attribute that was not found on the server.
    attr_reader :path

    # Create a new AttributeNotFoundError with the path to the erroneous
    # attribute.
    def initialize(path)
      @path = path
      super "Could not find attribute at #{@path}"
    end
  end

  # The server is at capacity and cannot accept anymore runs at this time.
  class ServerAtCapacityError < T2ServerError
    # Create a new ServerAtCapacityError.
    def initialize
      super "The server is already running its configured limit of " +
        "concurrent workflows."
    end
  end

  # Access to the entity (run or attribute) is denied. The credentials
  # supplied are not sufficient or the server does not allow the operation.
  class AccessForbiddenError < T2ServerError

    # The path of the attribute that the user is forbidden to access.
    attr_reader :path

    # Create a new AccessForbiddenError with the path to the restricted
    # attribute.
    def initialize(path)
      @path = path
      super "Access to #{@path} is forbidden. Either you do not have the " +
        "required credentials or the server does not allow the requested " +
        "operation"
    end
  end

  # Access to the server is denied to this username
  class AuthorizationError < T2ServerError

    # The username that has failed authorization.
    attr_reader :username

    # Create a new AuthorizationError with the rejected username
    def initialize(credentials)
      if credentials != nil
        @username = credentials.username
      else
        @username = ""
      end
      super "The username '#{@username}' is not authorized to connect to " +
        "this server"
    end
  end

  # Raised if an operation is performed on a run when it is in the wrong
  # state. Trying to start a run if it is the finished state would cause this
  # exception to be raised.
  class RunStateError < T2ServerError

    # Create a new RunStateError specifying both the current state and that
    # which is needed to run the operation.
    def initialize(current, need)
      super "The run is in the wrong state (#{current}); it should be " +
        "'#{need}' to perform that action"
    end
  end

  # Raised if the server wishes to redirect the connection. This typically
  # happens if a client tries to connect to a https server vis a http uri.
  class ConnectionRedirectError < T2ServerError

    # The redirected connection
    attr_reader :redirect

    # Create a new ConnectionRedirectError with the new, redirected,
    # connection supplied.
    def initialize(connection)
      @redirect = connection

      super "The server returned an unhandled redirect to '#{@redirect}'."
    end
  end
end
