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

require 'uri'
require 'net/https'

module T2Server

  # This is a factory for connections to a Taverna Server. It will return
  # either a http or https connection depending on what sort of uri is passed
  # into it. This class maintains a list of connections that it knows about
  # and will return an already established connection if it can.
  class ConnectionFactory

    private_class_method :new

    # list of connections we know about
    @@connections = []
    
    # :call-seq:
    #   ConnectionFactory.connect(uri) -> Connection
    #
    # Connect to a Taverna Server instance and return either a
    # T2Server::HttpConnection or T2Server::HttpsConnection object to
    # represent it.
    def ConnectionFactory.connect(uri, params = nil)
      # we want to use URIs here
      if !uri.is_a? URI
        raise URI::InvalidURIError.new
      end

      # if we're given params they must be of the right type
      if !params.nil? and !params.is_a? ConnectionParameters
        raise ArgumentError, "Parameters must be ConnectionParameters", caller
      end

      # see if we've already got this connection
      conn = @@connections.find {|c| c.uri == uri}

      if !conn
        if uri.scheme == "http"
          conn = HttpConnection.new(uri, params)
        elsif uri.scheme == "https"
          conn = HttpsConnection.new(uri, params)
        else
          raise URI::InvalidURIError.new
        end
        
        @@connections << conn
      end
      
      conn
    end
  end

  # A class representing a http connection to a Taverna Server. This class
  # should only ever be created via the T2Server::Connection factory class.
  class HttpConnection
    # The URI of this connection instance.
    attr_reader :uri

    # Open a http connection to the Taverna Server at the uri supplied. 
    def initialize(uri, params = nil)
      @uri = uri
      @params = params || DefaultConnectionParameters.new

      # set up http connection
      @http = Net::HTTP.new(@uri.host, @uri.port)
    end

    # :call-seq:
    #   POST_run(path, value, credentials) -> String
    #
    # Initialize a T2Server::Run on a server by uploading its workflow.
    # The new run's identifier (in String form) is returned.
    def POST_run(path, value, credentials)
      response = POST(path, value, "application/xml", credentials)
      
      case response
      when Net::HTTPCreated
        # return the identifier of the newly created run
        epr = URI.parse(response['location'])
        epr.path[-36..-1]
      when Net::HTTPForbidden
        raise ServerAtCapacityError.new
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(credentials)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    # :call-seq:
    #   POST_file(path, value, run, credentials) -> bool
    #
    # Upload a file to a run. If successful, true is returned.
    def POST_file(path, value, run, credentials)
      response = POST(path, value, "application/xml", credentials)
      
      case response
      when Net::HTTPCreated
        # OK, carry on...
        true
      when Net::HTTPNotFound
        raise RunNotFoundError.new(run)
      when Net::HTTPForbidden
        raise AccessForbiddenError.new("run #{run}")
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(credentials)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    # :call-seq:
    #   POST_dir(path, value, run, dir, credentials) -> bool
    #
    # Create a directory in the scratch space of a run. If successful, true
    # is returned.
    def POST_dir(path, value, run, dir, credentials)
      response = POST(path, value, "application/xml", credentials)
      
      case response
      when Net::HTTPCreated
        # OK, carry on...
        true
      when Net::HTTPNotFound
        raise RunNotFoundError.new(run)
      when Net::HTTPForbidden
        raise AccessForbiddenError.new("#{dir} on run #{run}")
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(credentials)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    # :call-seq:
    #   GET(path, type, range, credentials) -> String
    #
    # HTTP GET a resource at _path_ of _type_ from the server. If successful
    # the body of the response is returned. A portion of the data can be
    # retrieved by specifying a byte range, start..end, with the _range_
    # parameter.
    def GET(path, type, range, credentials)
      get = Net::HTTP::Get.new(path)
      get["Accept"] = type
      get["Range"] = "bytes=#{range.min}-#{range.max}" unless range.nil?
      credentials.authenticate(get) if credentials != nil
      
      begin
        response = @http.request(get)
      rescue InternalHTTPError => e
        raise ConnectionError.new(e)
      end
      
      case response
      when Net::HTTPOK, Net::HTTPPartialContent
        return response.body
      when Net::HTTPNoContent
        return nil
      when Net::HTTPMovedTemporarily
        new_conn = redirect(response["location"])
        raise ConnectionRedirectError.new(new_conn)
      when Net::HTTPNotFound
        raise AttributeNotFoundError.new(path)
      when Net::HTTPForbidden
        raise AccessForbiddenError.new("attribute #{path}")
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(credentials)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    # :call-seq:
    #   PUT(path, value, type, credentials) -> bool
    #
    # Perform a HTTP PUT of _value_ to a path on the server. If successful
    # true is returned.
    def PUT(path, value, type, credentials)
      put = Net::HTTP::Put.new(path)
      put.content_type = type
      credentials.authenticate(put) if credentials != nil
      
      begin
        response = @http.request(put, value)
      rescue InternalHTTPError => e
        raise ConnectionError.new(e)
      end
      
      case response
      when Net::HTTPOK
        # OK, so carry on
        true
      when Net::HTTPNotFound
        raise AttributeNotFoundError.new(path)
      when Net::HTTPForbidden
        raise AccessForbiddenError.new("attribute #{path}")
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(credentials)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    # :call-seq:
    #   POST(path, value, type, credentials)
    #
    # Perform an HTTP POST of _value_ to a path on the server. This method
    # should only be used by other, wrapper methods, that need to POST.
    def POST(path, value, type, credentials)
      post = Net::HTTP::Post.new(path)
      post.content_type = type
      credentials.authenticate(post) if credentials != nil
      
      begin
        @http.request(post, value)
      rescue InternalHTTPError => e
        raise ConnectionError.new(e)
      end
    end

    # :call-seq:
    #   DELETE(path, credentials) -> bool
    #
    # Perform an HTTP DELETE on a path on the server. If successful true
    # is returned.
    def DELETE(path, credentials)
      run = path.split("/")[-1]
      delete = Net::HTTP::Delete.new(path)
      credentials.authenticate(delete) if credentials != nil
      
      begin
        response = @http.request(delete)
      rescue InternalHTTPError => e
        raise ConnectionError.new(e)
      end
      
      case response
      when Net::HTTPNoContent
        # Success, carry on...
        true
      when Net::HTTPNotFound
        raise RunNotFoundError.new(run)
      when Net::HTTPForbidden
        raise AccessForbiddenError.new("run #{run}")
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(credentials)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    # :call-seq:
    #   OPTIONS(path, credentials) -> Hash
    #
    # Perform the HTTP OPTIONS command on the given _path_ and return a hash
    # of the headers returned.
    def OPTIONS(path, credentials)
      options = Net::HTTP::Options.new(path)
      credentials.authenticate(options) if credentials != nil

      begin
        response = @http.request(options)
      rescue InternalHTTPError => e
        raise ConnectionError.new(e)
      end

      case response
      when Net::HTTPOK
        response.to_hash
      when Net::HTTPForbidden
        raise AccessForbiddenError.new("resource #{path}")
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(credentials)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    private
    def redirect(location)
      uri = URI.parse(location)
      new_uri = URI::HTTP.new(uri.scheme, nil, uri.host, uri.port, nil,
        @uri.path, nil, nil, nil);
      ConnectionFactory.connect(new_uri, @params)
    end
  end

  # A class representing a https connection to a Taverna Server. This class
  # should only ever be created via the T2Server::Connection factory class.
  class HttpsConnection < HttpConnection

    # Open a https connection to the Taverna Server at the uri supplied.
    def initialize(uri, params = nil)
      super(uri, params)

      # Configure connection options using params
      @http.use_ssl = true

      # Peer verification
      if @params[:verify_peer]
        if @params[:ca_file]
          @http.ca_file = @params[:ca_file]
        else
          @http.ca_path = @params[:ca_path]
        end
        @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      else
        @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      # Client authentication
      if @params[:client_certificate]
        pem = File.read(@params[:client_certificate])
        @http.cert = OpenSSL::X509::Certificate.new(pem)
        @http.key = OpenSSL::PKey::RSA.new(pem, @params[:client_password])
      end
    end
  end  
end
