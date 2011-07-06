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

require 'rubygems'
require 'base64'
require 'uri'

module T2Server

  # An interface for directly communicating with one or more Taverna 2 Server
  # instances.
  class Server
    include XML::Methods

    # The version of the remote Taverna Server instance.
    attr_reader :version

    # :stopdoc:
    XPaths = {
      # Server top-level XPath queries
      :server   => XML::Methods.xpath_compile("//nsr:serverDescription"),
      :policy   => XML::Methods.xpath_compile("//nsr:policy"),
      :run      => XML::Methods.xpath_compile("//nsr:run"),
      :runs     => XML::Methods.xpath_compile("//nsr:runs"),

      # Server policy XPath queries
      :runlimit => XML::Methods.xpath_compile("//nsr:runLimit"),
      :permwkf  => XML::Methods.xpath_compile("//nsr:permittedWorkflows"),
      :permlstn => XML::Methods.xpath_compile("//nsr:permittedListeners"),
      :permlstt => XML::Methods.xpath_compile("//nsr:permittedListenerTypes"),
      :notify   => XML::Methods.xpath_compile("//nsr:enabledNotificationFabrics")
    }
    # :startdoc:

    def initialize(uri)
      # we want to use URIs here but strings can be passed in
      if !uri.is_a? URI
        uri = URI.parse(uri.strip_path);
      end

      # strip username and password from the URI if present
      if uri.user != nil
        uri = URI::HTTP.new(uri.scheme, nil, uri.host, uri.port, nil,
        uri.path, nil, nil, nil);
      end

      # setup connection
      @connection = Connection.connect(uri)

      # add a slash to the end of this address to work around this bug:
      # http://www.mygrid.org.uk/dev/issues/browse/TAVSERV-113
      server_description = xml_document(get_attribute("#{uri.path}/rest/",
        "application/xml"))
      @version = get_version(server_description)
      @links = get_description(server_description)

      # initialise run list
      @runs = {}
        
      yield(self) if block_given?
    end

    # :call-seq:
    #   Server.connect(uri, username="", password="") -> server
    #
    # Connect to the server specified by _uri_ which should be of the form:
    # http://example.com:8888/blah or https://user:pass@example.com:8888/blah
    #
    # The credentials to be used can also be passed in directly.
    # A Server instance is returned that represents the connection.
    def Server.connect(uri, username="", password="")
      new(uri)
    end

    # :call-seq:
    #   server.create_run(workflow, credentials = nil) -> run
    #
    # Create a run on this server using the specified _workflow_.
    def create_run(workflow, credentials = nil)
      uuid = initialize_run(workflow, credentials)
      run = Run.create(self, "", credentials, uuid)
      @runs[uuid] = run

      yield(run) if block_given?
      run
    end

    # :call-seq:
    #   server.initialize_run(workflow, credentials = nil) -> string
    #
    # Create a run on this server using the specified _workflow_ but do not
    # return it as a Run instance. Return its UUID instead.
    def initialize_run(workflow, credentials = nil)
      @connection.POST_run("#{@links[:runs]}",
        XML::Fragments::WORKFLOW % workflow, credentials)
    end

    # :call-seq:
    #   server.uri -> URI
    #
    # The URI of the connection to the remote Taverna Server.
    def uri
      @connection.uri
    end

    # :call-seq:
    #   server.run_limit(credentials = nil) -> num
    #
    # The maximum number of runs that this server will allow at any one time.
    # Runs in any state (+Initialized+, +Running+ and +Finished+) are counted
    # against this maximum.
    def run_limit(credentials = nil)
      get_attribute(@links[:runlimit], "text/plain", credentials).to_i
    end

    # :call-seq:
    #   server.runs(credentials = nil) -> [runs]
    #
    # Return the set of runs on this server.
    def runs(credentials = nil)
      get_runs(credentials).values
    end

    # :call-seq:
    #   server.run(uuid, credentials = nil) -> run
    #
    # Return the specified run.
    def run(uuid, credentials = nil)
      get_runs(credentials)[uuid]
    end

    # :call-seq:
    #   server.delete_run(run, credentials = nil) -> bool
    #
    # Delete the specified run from the server, discarding all of its state.
    # _run_ can be either a Run instance or a UUID.
    def delete_run(run, credentials = nil)
      # get the uuid from the run if that is what is passed in
      if run.instance_of? Run
        run = run.uuid
      end
      
      if @connection.DELETE("#{@links[:runs]}/#{run}", credentials)
        @runs.delete(run)
        true
      end
    end

    # :call-seq:
    #   server.delete_all_runs(credentials = nil)
    #
    # Delete all runs on this server, discarding all of their state.
    def delete_all_runs(credentials = nil)
      # first refresh run list
      runs(credentials).each {|run| run.delete}
    end

    # :call-seq:
    #   server.set_run_input(run, input, value, credentials = nil) -> bool
    #
    # Set the workflow input port _input_ on run _run_ to _value_. _run_ can
    # be either a Run instance or a UUID.
    def set_run_input(run, input, value, credentials = nil)
      # get the run from the uuid if that is what is passed in
      if not run.instance_of? Run
        run = run(run, credentials)
      end

      run.set_input(input, value)
    end

    # :call-seq:
    #   server.set_run_input_file(run, input, filename, credentials = nil) -> bool
    #
    # Set the workflow input port _input_ on run _run_ to use the file at
    # _filename_ for its input. _run_ can be either a Run instance or a UUID.
    def set_run_input_file(run, input, filename, credentials = nil)
      # get the run from the uuid if that is what is passed in
      if not run.instance_of? Run
        run = run(run, credentials)
      end

      run.set_input_file(input, filename)
    end

    # :call-seq:
    #   server.make_run_dir(run, root, dir, credentials = nil) -> bool
    #
    # Create a directory _dir_ within the directory _root_ on _run_. _run_ can
    # be either a Run instance or a UUID. This is mainly for use by Run#mkdir.
    def make_run_dir(run, root, dir, credentials = nil)
      # get the uuid from the run if that is what is passed in
      if run.instance_of? Run
        run = run.uuid
      end

      raise AccessForbiddenError.new("subdirectories (#{dir})") if dir.include? ?/
      @connection.POST_dir("#{@links[:runs]}/#{run}/#{root}",
        XML::Fragments::MKDIR % dir, run, dir, credentials)
    end

    # :call-seq:
    #   server.upload_run_file(run, filename, location, rename, credentials = nil) -> string
    #
    # Upload a file to _run_. _run_ can be either a Run instance or a UUID.
    # Mainly for internal use by Run#upload_file.
    def upload_run_file(run, filename, location, rename, credentials = nil)
      # get the uuid from the run if that is what is passed in
      if run.instance_of? Run
        run = run.uuid
      end

      contents = Base64.encode64(IO.read(filename))
      rename = filename.split('/')[-1] if rename == ""

      if @connection.POST_file("#{@links[:runs]}/#{run}/#{location}",
        XML::Fragments::UPLOAD % [rename, contents], run, credentials)
        rename
      end
    end

    # :call-seq:
    #   server.get_run_attribute(run, path, type, credentials = nil) -> string
    #
    # Get the attribute at _path_ in _run_. _run_ can be either a Run instance
    # or a UUID.
    def get_run_attribute(run, path, type, credentials = nil)
      # get the uuid from the run if that is what is passed in
      if run.instance_of? Run
        run = run.uuid
      end

      get_attribute("#{@links[:runs]}/#{run}/#{path}", type, credentials)
    rescue AttributeNotFoundError => e
      if get_runs(credentials).has_key? run
        raise e
      else
        raise RunNotFoundError.new(run)
      end
    end

    # :call-seq:
    #   server.set_run_attribute(run, path, value, type, credentials = nil) -> bool
    #
    # Set the attribute at _path_ in _run_ to _value_. _run_ can be either a
    # Run instance or a UUID.
    def set_run_attribute(run, path, value, type, credentials = nil)
      # get the uuid from the run if that is what is passed in
      if run.instance_of? Run
        run = run.uuid
      end

      set_attribute("#{@links[:runs]}/#{run}/#{path}", value, type,
        credentials)
    rescue AttributeNotFoundError => e
      if get_runs(credentials).has_key? run
        raise e
      else
        raise RunNotFoundError.new(run)
      end
    end

    private
    def get_attribute(path, type, credentials = nil)
      begin
        @connection.GET(path, type, credentials)
      rescue ConnectionRedirectError => cre
        @connection = cre.redirect
        retry
      end
    end

    def set_attribute(path, value, type, credentials = nil)
      @connection.PUT(path, value, type, credentials)
    end

    def get_version(doc)
      version = xpath_attr(doc, XPaths[:server], "serverVersion")
      if version == nil
        return 1.0
      else
        return version.to_f
      end
    end

    def get_description(doc)
      links = {}
      links[:runs] = URI.parse(xpath_attr(doc, XPaths[:runs], "href")).path

      if @version > 1.0
        links[:policy] = URI.parse(xpath_attr(doc, XPaths[:policy], "href")).path
        doc = xml_document(get_attribute(links[:policy], "application/xml"))
        
        links[:permlisteners] = URI.parse(xpath_attr(doc, XPaths[:permlstt], "href")).path
        links[:notifications] = URI.parse(xpath_attr(doc, XPaths[:notify], "href")).path
      else
        links[:permlisteners] = URI.parse(xpath_attr(doc, XPaths[:permlstn], "href")).path
      end
      
      links[:runlimit]      = URI.parse(xpath_attr(doc, XPaths[:runlimit], "href")).path
      links[:permworkflows] = URI.parse(xpath_attr(doc, XPaths[:permwkf], "href")).path

      links
    end

    def get_runs(credentials = nil)
      run_list = get_attribute("#{@links[:runs]}", "application/xml", credentials)

      doc = xml_document(run_list)

      # get list of run uuids
      uuids = []
      xpath_find(doc, XPaths[:run]).each do |run|
        uuids << run.attributes["href"].split('/')[-1]
      end

      # add new runs
      uuids.each do |uuid|
        if !@runs.has_key? uuid
          @runs[uuid] = Run.create(self, "", credentials, uuid)
        end
      end

      # clear out the expired runs
      if @runs.length > uuids.length
        @runs.delete_if {|key, val| !uuids.member? key}
      end

      @runs
    end
  end  
end
