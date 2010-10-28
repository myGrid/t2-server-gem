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

require 'rubygems'
require 'base64'
require 'uri'
require 'net/https'
require 'libxml'

module T2Server

  # An interface for directly communicating with one or more Taverna 2 Server
  # instances.
  class Server
    include LibXML

    private_class_method :new

    # The URI of this server instance as a String.
    attr_reader :uri
    
    # The maximum number of runs that this server will allow at any one time.
    # Runs in any state (+Initialized+, +Running+ and +Finished+) are counted
    # against this maximum.
    attr_reader :run_limit

    # list of servers we know about
    @@servers = []
    
    # :stopdoc:
    # New is private but rdoc does not get it right! Hence :stopdoc: section.
    def initialize(uri, username, password)
      @uri = uri.strip_path
      uri = URI.parse(@uri)
      @host = uri.host
      @port = uri.port
      @base_path = uri.path
      @rest_path = uri.path + "/rest"

      # set up http connection
      @http = Net::HTTP.new(@host, @port)

      # use ssl?
      @ssl = uri.scheme == "https"
      if ssl?
        @username = uri.user || username
        @password = uri.password || password
        
        @http.use_ssl = true
        @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      @links = parse_description(get_attribute(@rest_path))
      #@links.each {|key, val| puts "#{key}: #{val}"}
      
      # get max runs
      @run_limit = get_attribute(@links[:runlimit]).to_i
      
      # initialise run list
      @runs = {}
      @runs = get_runs
    end
    # :startdoc:

    # :call-seq:
    #   Server.connect(uri, username="", password="") -> server
    #
    # Connect to the server specified by _uri_ which should be of the form:
    # http://example.com:8888/blah or https://user:pass@example.com:8888/blah
    #
    # The username and password can also be passed in separately.
    # A Server instance is returned that represents the connection.
    def Server.connect(uri, username="", password="")
      # see if we've already got this server
      server = @@servers.find {|s| s.uri == uri}

      if !server
        # no, so create new one and return it
        server = new(uri, username, password)
        @@servers << server
      end
      
      server
    end

    # :call-seq:
    #   server.create_run(workflow) -> run
    #
    # Create a run on this server using the specified _workflow_.
    def create_run(workflow)
      uuid = initialize_run(workflow)
      @runs[uuid] = Run.create(self, "", uuid)
    end

    # :call-seq:
    #   server.initialize_run(workflow) -> string
    #
    # Create a run on this server using the specified _workflow_ but do not
    # return it as a Run instance. Return its UUID instead.
    def initialize_run(workflow)
      request = Net::HTTP::Post.new("#{@links[:runs]}")
      request.content_type = "application/xml"
      if ssl?
        request.basic_auth @username, @password
      end
      begin
        response = @http.request(request, Fragments::WORKFLOW % workflow)
      rescue InternalHTTPError => e
        raise ConnectionError.new(e)
      end
      
      case response
      when Net::HTTPCreated
        # return the uuid of the newly created run
        epr = URI.parse(response['location'])
        epr.path[-36..-1]
      when Net::HTTPForbidden
        raise ServerAtCapacityError.new(@run_limit)
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(@username)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    # :call-seq:
    #   server.ssl? -> bool
    #
    # Is this server using SSL?
    def ssl?
      @ssl
    end

    # :call-seq:
    #   server.runs -> [runs]
    #
    # Return the set of runs on this server.
    def runs
      get_runs.values
    end

    # :call-seq:
    #   server.run(uuid) -> run
    #
    # Return the specified run.
    def run(uuid)
      get_runs[uuid]
    end

    # :call-seq:
    #   server.delete_run(run) -> bool
    #
    # Delete the specified run from the server, discarding all of its state.
    # _run_ can be either a Run instance or a UUID.
    def delete_run(run)
      # get the uuid from the run if that is what is passed in
      if run.instance_of? Run
        run = run.uuid
      end

      request = Net::HTTP::Delete.new("#{@links[:runs]}/#{run}")
      if ssl?
        request.basic_auth @username, @password
      end
      begin
        response = @http.request(request)
      rescue InternalHTTPError => e
        raise ConnectionError.new(e)
      end
      
      case response
      when Net::HTTPNoContent
        # Success, carry on...
        @runs.delete(run)
        true
      when Net::HTTPNotFound
        raise RunNotFoundError.new(run)
      when Net::HTTPForbidden
        raise AccessForbiddenError.new("run #{run}")
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(@username)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    # :call-seq:
    #   server.delete_all_runs
    #
    # Delete all runs on this server, discarding all of their state.
    def delete_all_runs
      # first refresh run list
      runs.each {|run| run.delete}
    end

    # :call-seq:
    #   server.set_run_input(run, input, value) -> bool
    #
    # Set the workflow input port _input_ on run _run_ to _value_. _run_ can
    # be either a Run instance or a UUID.
    def set_run_input(run, input, value)
      # get the run from the uuid if that is what is passed in
      if not run.instance_of? Run
        run = run(run)
      end

      path = "#{@links[:runs]}/#{run.uuid}/#{run.inputs}/input/#{input}"
      set_attribute(path, Fragments::RUNINPUTVALUE % value, "application/xml")
    rescue AttributeNotFoundError => e
      if get_runs.has_key? run.uuid
        raise e
      else
        raise RunNotFoundError.new(run.uuid)
      end
    end

    # :call-seq:
    #   server.set_run_input_file(run, input, filename) -> bool
    #
    # Set the workflow input port _input_ on run _run_ to use the file at
    # _filename_ for its input. _run_ can be either a Run instance or a UUID.
    def set_run_input_file(run, input, filename)
      # get the run from the uuid if that is what is passed in
      if not run.instance_of? Run
        run = run(run)
      end

      path = "#{@links[:runs]}/#{run.uuid}/#{run.inputs}/input/#{input}"
      set_attribute(path, Fragments::RUNINPUTFILE % filename, "application/xml")
    rescue AttributeNotFoundError => e
      if get_runs.has_key? run.uuid
        raise e
      else
        raise RunNotFoundError.new(run.uuid)
      end
    end

    # :call-seq:
    #   server.make_run_dir(run, root, dir) -> bool
    #
    # Create a directory _dir_ within the directory _root_ on _run_. _run_ can
    # be either a Run instance or a UUID. This is mainly for use by Run#mkdir.
    def make_run_dir(run, root, dir)
      # get the uuid from the run if that is what is passed in
      if run.instance_of? Run
        run = run.uuid
      end

      raise AccessForbiddenError.new("subdirectories (#{dir})") if dir.include? ?/
      request = Net::HTTP::Post.new("#{@links[:runs]}/#{run}/#{root}")
      request.content_type = "application/xml"
      if ssl?
        request.basic_auth @username, @password
      end
      begin
        response = @http.request(request, Fragments::MKDIR % dir)
      rescue InternalHTTPError => e
        raise ConnectionError.new(e)
      end

      case response
      when Net::HTTPCreated
        # OK, carry on...
        true
      when Net::HTTPNotFound
        raise RunNotFoundError.new(run)
      when Net::HTTPForbidden
        raise AccessForbiddenError.new("#{dir} on run #{run}")
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(@username)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    # :call-seq:
    #   server.upload_run_file(run, filename, location, rename) -> string
    #
    # Upload a file to _run_. _run_ can be either a Run instance or a UUID.
    # Mainly for internal use by Run#upload_file.
    def upload_run_file(run, filename, location, rename)
      # get the uuid from the run if that is what is passed in
      if run.instance_of? Run
        run = run.uuid
      end

      contents = Base64.encode64(IO.read(filename))
      rename = filename.split('/')[-1] if rename == ""
      request = Net::HTTP::Post.new("#{@links[:runs]}/#{run}/#{location}")
      request.content_type = "application/xml"
      if ssl?
        request.basic_auth @username, @password
      end
      begin
        response = @http.request(request,  Fragments::UPLOAD % [rename, contents])
      rescue InternalHTTPError => e
        raise ConnectionError.new(e)
      end

      case response
      when Net::HTTPCreated
        # Success, return remote name of uploaded file
        rename
      when Net::HTTPNotFound
        raise RunNotFoundError.new(run)
      when Net::HTTPForbidden
        raise AccessForbiddenError.new("run #{run}")
      when Net::HTTPUnauthorized
        raise AuthorizationError.new(@username)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    # :call-seq:
    #   server.get_run_attribute(run, path) -> string
    #
    # Get the attribute at _path_ in _run_. _run_ can be either a Run instance
    # or a UUID.
    def get_run_attribute(run, path)
      # get the uuid from the run if that is what is passed in
      if run.instance_of? Run
        run = run.uuid
      end

      get_attribute("#{@links[:runs]}/#{run}/#{path}")
    rescue AttributeNotFoundError => e
      if get_runs.has_key? run
        raise e
      else
        raise RunNotFoundError.new(run)
      end
    end

    # :call-seq:
    #   server.set_run_attribute(run, path, value) -> bool
    #
    # Set the attribute at _path_ in _run_ to _value_. _run_ can be either a
    # Run instance or a UUID.
    def set_run_attribute(run, path, value)
      # get the uuid from the run if that is what is passed in
      if run.instance_of? Run
        run = run.uuid
      end

      set_attribute("#{@links[:runs]}/#{run}/#{path}", value, "text/plain")
    rescue AttributeNotFoundError => e
      if get_runs.has_key? run
        raise e
      else
        raise RunNotFoundError.new(run)
      end
    end

    private
    def get_attribute(path)
      request = Net::HTTP::Get.new(path)
      if ssl?
        request.basic_auth @username, @password
      end
      begin
        response = @http.request(request)
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
        raise AuthorizationError.new(@username)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    def set_attribute(path, value, type)
      request = Net::HTTP::Put.new(path)
      request.content_type = type
      if ssl?
        request.basic_auth @username, @password
      end
      begin
        response = @http.request(request, value)
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
        raise AuthorizationError.new(@username)
      else
        raise UnexpectedServerResponse.new(response)
      end
    end

    def parse_description(desc)
      doc = XML::Document.string(desc)
      nsmap = Namespaces::MAP
      {
        :runs          => URI.parse(doc.find_first(XPaths::RUNS, nsmap).attributes["href"]).path,
        :runlimit      => URI.parse(doc.find_first(XPaths::RUNLIMIT, nsmap).attributes["href"]).path,
        :permworkflows => URI.parse(doc.find_first(XPaths::PERMWKF, nsmap).attributes["href"]).path,
        :permlisteners => URI.parse(doc.find_first(XPaths::PERMLSTN, nsmap).attributes["href"]).path
      }
    end

    def get_runs
      run_list = get_attribute("#{@links[:runs]}")

      doc = XML::Document.string(run_list)

      # get list of run uuids
      uuids = []
      doc.find(XPaths::RUN, Namespaces::MAP).each do |run|
        uuids << run.attributes["href"].split('/')[-1]
      end

      # add new runs
      uuids.each do |uuid|
        if !@runs.has_key? uuid
          @runs[uuid] = Run.create(self, "", uuid)
        end
      end

      # clear out the expired runs
      if @runs.length > @run_limit
        @runs.delete_if {|key, val| !uuids.member? key}
      end

      @runs
    end
  end  
end
