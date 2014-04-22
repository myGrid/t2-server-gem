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
require 't2-server/run-cache'

module T2Server

  # An interface for directly communicating with one or more Taverna 2 Server
  # instances.
  class Server
    include XML::Methods

    # :stopdoc:
    # Internal references to the main rest and admin top-level resource
    # endpoints.
    REST_ENDPOINT = "rest/"

    XPATHS = {
      # Server top-level XPath queries
      :server   => "//nsr:serverDescription",
      :policy   => "//nsr:policy",
      :run      => "//nsr:run",
      :runs     => "//nsr:runs",

      # Server policy XPath queries
      :runlimit      => "//nsr:runLimit",
      :permworkflows => "//nsr:permittedWorkflows",
      :permlisteners => "//nsr:permittedListenerTypes",
      :notifications => "//nsr:enabledNotificationFabrics"
    }

    @@xpaths = XML::XPathCache.instance
    @@xpaths.register_xpaths XPATHS
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
      # Convert strings to URIs and strip any credentials that have been given
      # in the URI. We do not want to store credentials in this class.
      uri, creds = Util.strip_uri_credentials(uri)

      # setup connection
      @connection = ConnectionFactory.connect(uri, params)

      # The following four fields hold cached data about the server that is
      # only downloaded the first time it is requested.
      @server_doc = nil
      @version = nil
      @version_components = nil
      @links = nil

      # Initialize the run object cache.
      @run_cache = RunCache.new(self)

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
      uri = initialize_run(workflow, credentials)
      run = Run.create(self, "", credentials, uri)

      # Add the newly created run object to the user's run cache
      @run_cache.add_run(run, credentials)

      yield(run) if block_given?
      run
    end

    # :stopdoc:
    # Create a run on this server using the specified _workflow_ and return
    # the URI to it.
    #
    # We need to catch AccessForbiddenError here to be compatible with Server
    # versions pre 2.4.2. When we no longer support them we can remove the
    # rescue clause of this method.
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
    rescue AccessForbiddenError => afe
      if version >= "2.4.2"
        # Need to re-raise as it's a real error for later versions.
        raise afe
      else
        raise ServerAtCapacityError.new
      end
    end
    # :startdoc:

    # :call-seq:
    #   version -> Server::Version
    #
    # An object representing the version of the remote Taverna Server.
    def version
      @version ||= _get_version
    end

    # :call-seq:
    #   version_components -> array
    #
    # An array of the major, minor and patch version components of the remote
    # Taverna Server.
    def version_components
      warn "[DEPRECATED] Server#version_components is deprecated and will "\
        "be removed in the next major release. Please use "\
        "Server#version.to_a instead."

      version.to_a
    end

    # :call-seq:
    #   uri -> URI
    #
    # The URI of the connection to the remote Taverna Server.
    def uri
      @connection.uri
    end

    # :call-seq:
    #   run_limit(credentials = nil) -> fixnum
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
      # Refresh run list, delete everything, clear the user's run cache.
      runs(credentials).each {|run| run.delete}
      @run_cache.clear!(credentials)
    end

    # :stopdoc:
    def mkdir(uri, dir, credentials = nil)
      @connection.POST(uri, XML::Fragments::MKDIR % dir, "application/xml",
        credentials)
    end

    def upload_file(filename, uri, remote_name, credentials = nil)
      remote_name = filename.split('/')[-1] if remote_name == ""

      # Different Server versions support different upload methods
      if version >= "2.4.1"
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
      if version >= "2.4.1"
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
    rescue AttributeNotFoundError => ane
      # Ignore this. Delete is idempotent so deleting something that has
      # already been deleted, or is for some other reason not there, should
      # happen silently. Return true here because when deleting it's enough to
      # know that it's no longer there rather than whether it was deleted
      # *this time* or not.
      true
    end
    # :startdoc:

    private

    def links
      @links ||= _get_server_links
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
      version = xpath_attr(doc, @@xpaths[:server], "serverVersion")

      if version.nil?
        raise RuntimeError.new("Taverna Servers prior to version 2.3 " +
          "are no longer supported.")
      end

      Version.new(version)
    end

    def _get_server_links
      doc = _get_server_description
      links = get_uris_from_doc(doc, [:runs, :policy])

      doc = xml_document(read(links[:policy], "application/xml"))
      links.merge get_uris_from_doc(doc,
        [:permlisteners, :notifications, :runlimit, :permworkflows])
    end

    def get_runs(credentials = nil)
      run_list = read(links[:runs], "application/xml", credentials)

      doc = xml_document(run_list)

      # get list of run identifiers
      run_list = {}
      xpath_find(doc, @@xpaths[:run]).each do |run|
        uri = URI.parse(xml_node_attribute(run, "href"))
        id = xml_node_content(run)
        run_list[id] = uri
      end

      # Refresh the user's cache and return the runs in it.
      @run_cache.refresh_all!(run_list, credentials)
    end

    # :stopdoc:
    class Version
      include Comparable

      def initialize(version)
        @string = parse_version(version)
        @array = []
      end

      def to_s
        @string
      end

      def to_a
        if @array.empty?
          comps = @string.split(".")
          @array = comps.map { |v| v.to_i }
        end

        @array
      end

      def <=>(other)
        other = Version.new(other) if other.instance_of?(String)
        self.to_a.zip(other.to_a).each do |c|
          comp = c[0] <=> c[1]
          return comp unless comp == 0
        end

        # If we get here then we know we have equal version numbers.
        0
      end

      private

      def parse_version(version)
        # Remove extra version tags if present.
        version.gsub!("-SNAPSHOT", "")
        version.gsub!(/alpha[0-9]*/, "")

        # Add .0 if we only have a major and minor component.
        if version.split(".").length == 2
          version += ".0"
        end

        version
      end
    end
    # :startdoc:

  end
end
