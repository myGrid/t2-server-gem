# Copyright (c) 2010, 2011 The University of Manchester, UK.
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

  # use abstract factory!
  class Connection

    private_class_method :new

    # list of connections we know about
    @@connections = []
    
    def Connection.connect(uri)
      # we want to use URIs here
      if !uri.is_a? URI
        raise URI::InvalidURIError.new
      end
      
      # see if we've already got this connection
      conn = @@connections.find {|c| c.uri == uri}

      if !conn
        if uri.scheme == "http"
          conn = HttpConnection.new(uri)
        elsif uri.scheme == "https"
          conn = HttpsConnection.new(uri)
        else
          raise URI::InvalidURIError.new
        end
        
        @@connections << conn
      end
      
      conn
    end
  end
  
  class HttpConnection
    # The URI of this connection instance.
    attr_reader :uri

    def initialize(uri)
      @uri = uri

      # set up http connection
      @http = Net::HTTP.new(@uri.host, @uri.port)
    end
    
    def POST_run(path, value, limit, credentials)
      response = POST(path, value, "application/xml", credentials)
      
      case response
      when Net::HTTPCreated
        # return the uuid of the newly created run
        epr = URI.parse(response['location'])
        epr.path[-36..-1]
      when Net::HTTPForbidden
        raise ServerAtCapacityError.new(limit)
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(credentials)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end
    
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
    
    def GET(path, credentials)
      get = Net::HTTP::Get.new(path)
      credentials.authenticate(get) if credentials != nil
      
      begin
        response = @http.request(get)
      rescue InternalHTTPError => e
        raise ConnectionError.new(e)
      end
      
      case response
      when Net::HTTPOK
        return response.body
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
  end
  
  class HttpsConnection < HttpConnection
    def initialize(uri)
      super(uri)
      
      @http.use_ssl = true
      # probably shouldn't do this, but...
      @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
  end  
end
