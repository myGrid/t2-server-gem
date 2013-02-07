# Copyright (c) 2010-2013 The University of Manchester, UK.
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

require 'base64'
require 'uri'

module T2Server

  # An interface for directly communicating with one or more Taverna 2 Server
  # instances.
  class Server
    include XML::Methods

    # :stopdoc:
    # Internal references to the main rest and admin top-level resource
    # endpoints.
    REST_ENDPOINT = "rest/"

    XPaths = {
      # Server top-level XPath queries
      :server   => XML::Methods.xpath_compile("//nsr:serverDescription"),
      :policy   => XML::Methods.xpath_compile("//nsr:policy"),
      :run      => XML::Methods.xpath_compile("//nsr:run"),
      :runs     => XML::Methods.xpath_compile("//nsr:runs"),
      :intfeed  => XML::Methods.xpath_compile("//nsr:interactionFeed"),

      # Server policy XPath queries
      :runlimit => XML::Methods.xpath_compile("//nsr:runLimit"),
      :permwkf  => XML::Methods.xpath_compile("//nsr:permittedWorkflows"),
      :permlstn => XML::Methods.xpath_compile("//nsr:permittedListeners"),
      :permlstt => XML::Methods.xpath_compile("//nsr:permittedListenerTypes"),
      :notify   =>
        XML::Methods.xpath_compile("//nsr:enabledNotificationFabrics")
    }
    # :startdoc:

    # :call-seq:
    #   new(uri, connection_parameters = nil) -> Server
    #   new(uri, connection_parameters = nil) {|self| ...}
    #
    # Create a new Server instance that represents the real server at _uri_.
    # If _connection_parameters_ are supplied they will be used to set up the
    # network connection to the server.
    #
    # It will _yield_ itself if a block is given.
    def initialize(uri, params = nil)
      # we want to use URIs here but strings can be passed in
      unless uri.is_a? URI
        uri = URI.parse(Util.strip_path_slashes(uri))
      end

      # strip username and password from the URI if present
      if uri.user != nil
        uri = URI::HTTP.new(uri.scheme, nil, uri.host, uri.port, nil,
        uri.path, nil, nil, nil);
      end

      # setup connection
      @connection = ConnectionFactory.connect(uri, params)

      # The following four fields hold cached data about the server that is
      # only downloaded the first time it is requested.
      @server_doc = nil
      @version = nil
      @version_components = nil
      @interaction_feed = nil
      @links = nil

      # initialize run object cache
      @runs = {}

      yield(self) if block_given?
    end

    # :call-seq:
    #   administrator(credentials = nil) -> Administrator
    #   administrator(credentials = nil) {|admin| ...}
    #
    # Return an instance of the Taverna Server administrator interface. This
    # method will _yield_ the newly created administrator if a block is given.
    def administrator(credentials = nil)
      admin = Administrator.new(self, credentials)

      yield(admin) if block_given?
      admin
    end

    # :call-seq:
    #   create_run(workflow, credentials = nil) -> run
    #   create_run(workflow, credentials = nil) {|run| ...}
    #
    # Create a run on this server using the specified _workflow_.
    # This method will _yield_ the newly created Run if a block is given.
    #
    # The _workflow_ parameter may be the workflow itself, a file name or a
    # File or IO object.
    def create_run(workflow, credentials = nil)
      id = initialize_run(workflow, credentials)
      run = Run.create(self, "", credentials, id)

      # cache newly created run object in the user's run cache
      user_runs(credentials)[run.id] = run

      yield(run) if block_given?
      run
    end

    # :stopdoc:
    # Create a run on this server using the specified _workflow_ but do not
    # return it as a Run instance. Return its identifier instead.
    def initialize_run(workflow, credentials = nil)
      # If workflow is a String, it might be a filename! If so, stream it.
      if (workflow.instance_of? String) && (File.file? workflow)
        return File.open(workflow, "r") do |file|
          create(links[:runs], file, "application/vnd.taverna.t2flow+xml",
            credentials)
        end
      end

      # If we get here then workflow could either be a String containing a
      # workflow or a File or IO object.
      create(links[:runs], workflow, "application/vnd.taverna.t2flow+xml",
        credentials)
    end
    # :startdoc:

    # :call-seq:
    #   version -> String
    #
    # The version string of the remote Taverna Server.
    def version
      if @version.nil?
        @version = _get_version
      end

      @version
    end

    # :call-seq:
    #   version_components -> Array
    #
    # An array of the major, minor and patch version components of the remote
    # Taverna Server.
    def version_components
      if @version_components.nil?
        comps = version.split(".")
        @version_components = comps.map { |v| v.to_i }
      end

      @version_components
    end

    # :call-seq:
    #   uri -> URI
    #
    # The URI of the connection to the remote Taverna Server.
    def uri
      @connection.uri
    end

    # :call-seq:
    #   has_interaction_support? -> Boolean
    #
    # Does this server support interactions and provide a feed for them?
    def has_interaction_support?
      !links[:intfeed].nil?
    end

    # :call-seq:
    #   run_limit(credentials = nil) -> num
    #
    # The maximum number of runs that this server will allow at any one time.
    # Runs in any state (+Initialized+, +Running+ and +Finished+) are counted
    # against this maximum.
    def run_limit(credentials = nil)
      read(links[:runlimit], "text/plain", credentials).to_i
    end

    # :call-seq:
    #   runs(credentials = nil) -> [runs]
    #
    # Return the set of runs on this server.
    def runs(credentials = nil)
      get_runs(credentials).values
    end

    # :call-seq:
    #   run(identifier, credentials = nil) -> run
    #
    # Return the specified run.
    def run(identifier, credentials = nil)
      get_runs(credentials)[identifier]
    end

    # :call-seq:
    #   delete_all_runs(credentials = nil)
    #
    # Delete all runs on this server, discarding all of their state. Note that
    # only those runs that the provided credentials have permission to delete
    # will be deleted.
    def delete_all_runs(credentials = nil)
      # first refresh run list
      runs(credentials).each {|run| run.delete}
    end

    # :stopdoc:
    def mkdir(uri, dir, credentials = nil)
      @connection.POST(uri, XML::Fragments::MKDIR % dir, "application/xml",
        credentials)
    end

    def upload_file(filename, uri, remote_name, credentials = nil)
      # Different Server versions support different upload methods
      (major, minor, patch) = version_components

      remote_name = filename.split('/')[-1] if remote_name == ""

      if minor == 4 && patch >= 1
        File.open(filename, "rb") do |file|
          upload_data(file, remote_name, uri, credentials)
        end
      else
        contents = IO.read(filename)
        upload_data(contents, remote_name, uri, credentials)
      end
    end

    def upload_data(data, remote_name, uri, credentials = nil)
      # Different Server versions support different upload methods
      (major, minor, patch) = version_components

      if minor == 4 && patch >= 1
        put_uri = Util.append_to_uri_path(uri, remote_name)
        @connection.PUT(put_uri, data, "application/octet-stream", credentials)
      else
        contents = Base64.encode64(data)
        @connection.POST(uri,
          XML::Fragments::UPLOAD % [remote_name, contents], "application/xml",
          credentials)
      end
    end

    def is_resource_writable?(uri, credentials = nil)
      headers = @connection.OPTIONS(uri, credentials)
      headers["allow"][0].split(",").include? "PUT"
    end

    def create(uri, value, type, credentials = nil)
      @connection.POST(uri, value, type, credentials)
    end

    def read(uri, type, *rest, &block)
      credentials = nil
      range = nil

      rest.each do |param|
        case param
        when HttpCredentials
          credentials = param
        when Range
          range = param
        when Array
          range = param[0]..param[1]
        end
      end

      begin
        @connection.GET(uri, type, range, credentials, &block)
      rescue ConnectionRedirectError => cre
        # We've been redirected so save the new connection object with the new
        # server URI and try again with the new URI.
        @connection = cre.redirect
        uri = Util.replace_uri_path(@connection.uri, uri.path)
        retry
      end
    end

    # An internal helper to write streamed data directly to another stream.
    # The number of bytes written to the stream is returned. The stream passed
    # in may be anything that provides a +write+ method; instances of IO and
    # File, for example.
    def read_to_stream(stream, uri, type, *rest)
      raise ArgumentError,
        "Stream passed in must provide a write method" unless
          stream.respond_to? :write

      bytes = 0

      read(uri, type, *rest) do |chunk|
        bytes += stream.write(chunk)
      end

      bytes
    end

    # An internal helper to write streamed data straight to a file.
    def read_to_file(filename, uri, type, *rest)
      File.open(filename, "wb") do |file|
        read_to_stream(file, uri, type, *rest)
      end
    end

    def update(uri, value, type, credentials = nil)
      @connection.PUT(uri, value, type, credentials)
    end

    def delete(uri, credentials = nil)
      @connection.DELETE(uri, credentials)
    end

    def interaction_reader(run)
      @interaction_feed ||= Interaction::Feed.new(links[:intfeed])

      Interaction::Reader.new(@interaction_feed, run)
    end
    # :startdoc:

    private

    def links
      @links = _get_server_links if @links.nil?

      @links
    end

    def _get_server_description
      if @server_doc.nil?
        rest_uri = Util.append_to_uri_path(uri, REST_ENDPOINT)
        @server_doc = xml_document(read(rest_uri, "application/xml"))
      end

      @server_doc
    end

    def _get_version
      doc = _get_server_description
      version = xpath_attr(doc, XPaths[:server], "serverVersion")
      if version == nil
        raise RuntimeError.new("Taverna Servers prior to version 2.3 " +
          "are no longer supported.")
      else
        # Remove SNAPSHOT tag if it's there.
        if version.end_with? "-SNAPSHOT"
          version.gsub!("-SNAPSHOT", "")
        end

        # Add .0 if we only have a major and minor component.
        if version.split(".").length == 2
          version += ".0"
        end

        return version
      end
    end

    def _get_server_links
      doc = _get_server_description
      links = {}
      links[:runs] = URI.parse(xpath_attr(doc, XPaths[:runs], "href"))
      uri = xpath_attr(doc, XPaths[:intfeed], "href")
      links[:intfeed] = uri.nil? ? nil : URI.parse(uri)

      links[:policy] = URI.parse(xpath_attr(doc, XPaths[:policy], "href"))
      doc = xml_document(read(links[:policy], "application/xml"))

      links[:permlisteners] =
        URI.parse(xpath_attr(doc, XPaths[:permlstt], "href"))
      links[:notifications] =
        URI.parse(xpath_attr(doc, XPaths[:notify], "href"))

      links[:runlimit]      =
        URI.parse(xpath_attr(doc, XPaths[:runlimit], "href"))
      links[:permworkflows] =
        URI.parse(xpath_attr(doc, XPaths[:permwkf], "href"))

      links
    end

    def get_runs(credentials = nil)
      run_list = read(links[:runs], "application/xml", credentials)

      doc = xml_document(run_list)

      # get list of run identifiers
      run_list = {}
      xpath_find(doc, XPaths[:run]).each do |run|
        uri = URI.parse(xml_node_attribute(run, "href"))
        id = xml_node_content(run)
        run_list[id] = uri
      end

      # cache run objects in the user's run cache
      runs_cache = user_runs(credentials)

      # add new runs to the user cache
      run_list.each_key do |id|
        if !runs_cache.has_key? id
          runs_cache[id] = Run.create(self, "", credentials, run_list[id])
        end
      end

      # clear out the expired runs
      if runs_cache.length > run_list.length
        runs_cache.delete_if {|key, val| !run_list.member? key}
      end

      runs_cache
    end

    def user_runs(credentials = nil)
      user = credentials.nil? ? :all : credentials.username
      @runs[user] ||= {}
    end
  end
end
