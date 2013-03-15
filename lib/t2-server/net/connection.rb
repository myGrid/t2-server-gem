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
require 'net/http/persistent'

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

      # set up persistent http connection
      @http = Net::HTTP::Persistent.new("Taverna_Server_Ruby_Client")
    end

    # :call-seq:
    #   GET(uri, type, range, credentials) -> String
    #
    # HTTP GET a resource at _uri_ of _type_ from the server. If successful
    # the body of the response is returned. A portion of the data can be
    # retrieved by specifying a byte range, start..end, with the _range_
    # parameter.
    def GET(uri, type, range, credentials, &block)
      get = Net::HTTP::Get.new(uri.path)
      get["Accept"] = type
      get["Range"] = "bytes=#{range.min}-#{range.max}" unless range.nil?

      response = submit(get, uri, credentials, &block)

      case response
      when Net::HTTPOK, Net::HTTPPartialContent
        return response.body
      when Net::HTTPNoContent
        return nil
      when Net::HTTPMovedTemporarily
        new_conn = redirect(response["location"])
        raise ConnectionRedirectError.new(new_conn)
      when Net::HTTPNotFound
        raise AttributeNotFoundError.new(uri.path)
      when Net::HTTPForbidden
        raise AccessForbiddenError.new("attribute #{uri.path}")
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(credentials)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    # :call-seq:
    #   PUT(uri, value, type, credentials) -> bool
    #   PUT(uri, value, type, credentials) -> URI
    #   PUT(uri, stream, type, credentials) -> URI
    #
    # Upload data via HTTP PUT. Data may be specified as a value or as a
    # stream. The stream can be any object that has a read(length) method;
    # instances of File or IO, for example.
    #
    # If successful _true_ or a URI to the uploaded resource is returned
    # depending on whether the operation has altered a parameter (true) or
    # uploaded new data (URI).
    def PUT(uri, data, type, credentials)
      put = Net::HTTP::Put.new(uri.path)
      put.content_type = type

      set_upload_body(put, data)

      response = submit(put, uri, credentials)

      case response
      when Net::HTTPOK
        # We've set a parameter so we get 200 back from the server. Return
        # true to indicate success.
        true
      when Net::HTTPCreated
        # We've uploaded data so we get 201 back from the server. Return the
        # uri of the created resource.
        URI.parse(response['location'])
      when Net::HTTPNoContent
        # We've modified data so we get 204 back from the server. Return the
        # uri of the modified resource.
        uri
      when Net::HTTPNotFound
        raise AttributeNotFoundError.new(uri.path)
      when Net::HTTPForbidden
        raise AccessForbiddenError.new("attribute #{uri.path}")
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(credentials)
      when Net::HTTPServiceUnavailable
        raise ServerAtCapacityError.new
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    # :call-seq:
    #   POST(uri, value, type, credentials) -> URI
    #   POST(uri, stream, type, credentials) -> URI
    #
    # Upload data via HTTP POST. Data may be specified as a value or as a
    # stream. The stream can be any object that has a read(length) method;
    # instances of File or IO, for example.
    #
    # If successful the URI of the uploaded resource is returned.
    def POST(uri, data, type, credentials)
      post = Net::HTTP::Post.new(uri.path)
      post.content_type = type

      set_upload_body(post, data)

      response = submit(post, uri, credentials)

      case response
      when Net::HTTPCreated
        # return the URI of the newly created item
        URI.parse(response['location'])
      when Net::HTTPNotFound
        raise AttributeNotFoundError.new(uri.path)
      when Net::HTTPForbidden
        raise AccessForbiddenError.new("attribute #{uri.path}")
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(credentials)
      when Net::HTTPServiceUnavailable
        raise ServerAtCapacityError.new
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    # :call-seq:
    #   DELETE(uri, credentials) -> bool
    #
    # Perform an HTTP DELETE on a _uri_ on the server. If successful true
    # is returned.
    def DELETE(uri, credentials)
      delete = Net::HTTP::Delete.new(uri.path)

      response = submit(delete, uri, credentials)

      case response
      when Net::HTTPNoContent
        # Success, carry on...
        true
      when Net::HTTPNotFound
        raise AttributeNotFoundError.new(uri.path)
      when Net::HTTPForbidden
        raise AccessForbiddenError.new(uri)
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(credentials)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    # :call-seq:
    #   OPTIONS(uri, credentials) -> Hash
    #
    # Perform the HTTP OPTIONS command on the given _uri_ and return a hash
    # of the headers returned.
    def OPTIONS(uri, credentials)
      options = Net::HTTP::Options.new(uri.path)

      response = submit(options, uri, credentials)

      case response
      when Net::HTTPOK
        response.to_hash
      when Net::HTTPForbidden
        raise AccessForbiddenError.new("resource #{uri.path}")
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(credentials)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    private

    # If we have a stream then we need to set body_stream and then either
    # supply a content length or set the transfer encoding to "chunked". A
    # file object can supply its size, a bare IO object cannot. If we have a
    # simple value we can set body directly.
    def set_upload_body(request, data)
      if data.respond_to? :read
        request.body_stream = data
        if data.respond_to? :size
          request.content_length = data.size
        else
          request["Transfer-encoding"] = "chunked"
        end
      else
        request.body = data
      end
    end

    # If a block is passed in here then the response is returned in chunks
    # (streamed). If no block is passed in the whole response is read into
    # memory and returned.
    def submit(request, uri, credentials, &block)

      credentials.authenticate(request) unless credentials.nil?

      response = nil
      begin
        @http.request(uri, request) do |r|
          r.read_body(&block)
          response = r
        end
        response
      rescue InternalHTTPError => e
        raise ConnectionError.new(e)
      end
    end

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

      @http.ssl_version ||= params[:ssl_version]

      # Peer verification
      if @params[:verify_peer]
        if @params[:ca_file]
          @http.ca_file = @params[:ca_file]
        end

        if @params[:ca_path]
          store = OpenSSL::X509::Store.new
          store.set_default_paths
          if @params[:ca_path].is_a? Array
            @params[:ca_path].each { |path| store.add_path(path) }
          else
            store.add_path(@params[:ca_path])
          end

          @http.cert_store = store
        end

        @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      else
        @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      # Client authentication
      if @params[:client_certificate]
        pem = File.read(@params[:client_certificate])
        @http.certificate = OpenSSL::X509::Certificate.new(pem)
        @http.private_key = OpenSSL::PKey::RSA.new(pem,
          @params[:client_password])
      end
    end
  end
end
