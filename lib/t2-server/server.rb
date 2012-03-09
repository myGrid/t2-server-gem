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

      # add a slash to the end of this address to work around this bug:
      # http://www.mygrid.org.uk/dev/issues/browse/TAVSERV-113
      server_description = xml_document(get_attribute("#{uri.path}/rest/",
        "application/xml"))
      @version = get_version(server_description)
      @links = get_description(server_description)
      @links[:admin] = "#{uri.path}/admin"

      # initialize run object cache
      @runs = {}

      yield(self) if block_given?
    end

    # :stopdoc:
    def Server.connect(uri, username="", password="")
      warn "[DEPRECATION] 'Server#connect' is deprecated and will be " +
        "removed in 1.0."
      new(uri)
    end
    # :startdoc:

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
    def create_run(workflow, credentials = nil)
      id = initialize_run(workflow, credentials)
      run = Run.create(self, "", credentials, id)

      # cache newly created run object - this must be done per user
      user = credentials.nil? ? :all : credentials.username
      @runs[user] = {} unless @runs[user]
      @runs[user][id] = run

      yield(run) if block_given?
      run
    end

    # :call-seq:
    #   initialize_run(workflow, credentials = nil) -> string
    #
    # Create a run on this server using the specified _workflow_ but do not
    # return it as a Run instance. Return its identifier instead.
    def initialize_run(workflow, credentials = nil)
      # set up the run object cache - this must be done per user
      user = credentials.nil? ? :all : credentials.username
      @runs[user] = {} unless @runs[user]

      @connection.POST_run("#{@links[:runs]}",
        XML::Fragments::WORKFLOW % workflow, credentials)
    end

    # :call-seq:
    #   uri -> URI
    #
    # The URI of the connection to the remote Taverna Server.
    def uri
      @connection.uri
    end

    # :call-seq:
    #   run_limit(credentials = nil) -> num
    #
    # The maximum number of runs that this server will allow at any one time.
    # Runs in any state (+Initialized+, +Running+ and +Finished+) are counted
    # against this maximum.
    def run_limit(credentials = nil)
      get_attribute(@links[:runlimit], "text/plain", credentials).to_i
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
    #   delete_run(run, credentials = nil) -> bool
    #
    # Delete the specified run from the server, discarding all of its state.
    # _run_ can be either a Run instance or a identifier.
    def delete_run(run, credentials = nil)
      # get the identifier from the run if that is what is passed in
      if run.instance_of? Run
        run = run.identifier
      end

      if delete_attribute("#{@links[:runs]}/#{run}", credentials)
        # delete cached run object - this must be done per user
        user = credentials.nil? ? :all : credentials.username
        @runs[user].delete(run)
        true
      end
    end

    # :call-seq:
    #   delete_all_runs(credentials = nil)
    #
    # Delete all runs on this server, discarding all of their state.
    def delete_all_runs(credentials = nil)
      # first refresh run list
      runs(credentials).each {|run| run.delete}
    end

    # :stopdoc:
    def set_run_input(run, input, value, credentials = nil)
      warn "[DEPRECATION] 'Server#set_run_input' is deprecated and will be " +
        "removed in 1.0. Input ports are set directly instead. The most " +
        "direct replacement for this method is: " +
        "'Run#input_port(input).value = value'"

      # get the run from the identifier if that is what is passed in
      if not run.instance_of? Run
        run = run(run, credentials)
      end

      run.input_port(input).value = value
    end

    def set_run_input_file(run, input, filename, credentials = nil)
      warn "[DEPRECATION] 'Server#set_run_input_file' is deprecated and " +
        "will be removed in 1.0. Input ports are set directly instead. The " +
        "most direct replacement for this method is: " +
        "'Run#input_port(input).remote_file = filename'"

      # get the run from the identifier if that is what is passed in
      if not run.instance_of? Run
        run = run(run, credentials)
      end

      run.input_port(input).remote_file = filename
    end

    def create_dir(run, root, dir, credentials = nil)
      # get the identifier from the run if that is what is passed in
      if run.instance_of? Run
        run = run.identifier
      end

      raise AccessForbiddenError.new("subdirectories (#{dir})") if dir.include? ?/
      @connection.POST_dir("#{@links[:runs]}/#{run}/#{root}",
        XML::Fragments::MKDIR % dir, run, dir, credentials)
    end

    def make_run_dir(run, root, dir, credentials = nil)
      warn "[DEPRECATION] 'Server#make_run_dir' is deprecated and will be " +
        "removed in 1.0. Please use 'Run#mkdir' instead."

      create_dir(run, root, dir, credentials)
    end

    def upload_file(run, filename, location, rename, credentials = nil)
      # get the identifier from the run if that is what is passed in
      if run.instance_of? Run
        run = run.identifier
      end

      contents = Base64.encode64(IO.read(filename))
      rename = filename.split('/')[-1] if rename == ""

      if @connection.POST_file("#{@links[:runs]}/#{run}/#{location}",
        XML::Fragments::UPLOAD % [rename, contents], run, credentials)
        rename
      end
    end

    def upload_run_file(run, filename, location, rename, credentials = nil)
      warn "[DEPRECATION] 'Server#upload_run_file' is deprecated and will " +
        "be removed in 1.0. Please use 'Run#upload_file' or " +
        "'Run#input_port(input).file = filename' instead."

      upload_file(run, filename, location, rename, credentials)
    end

    def create_run_attribute(run, path, value, type, credentials = nil)
      # get the identifier from the run if that is what is passed in
      if run.instance_of? Run
        run = run.identifier
      end

      create_attribute("#{@links[:runs]}/#{run}/#{path}", value, type,
        credentials)
      rescue AttributeNotFoundError => e
      if get_runs(credentials).has_key? run
        raise e
      else
        raise RunNotFoundError.new(run)
      end
    end

    def get_run_attribute(run, path, type, credentials = nil)
      # get the identifier from the run if that is what is passed in
      if run.instance_of? Run
        run = run.identifier
      end

      get_attribute("#{@links[:runs]}/#{run}/#{path}", type, credentials)
    rescue AttributeNotFoundError => e
      if get_runs(credentials).has_key? run
        raise e
      else
        raise RunNotFoundError.new(run)
      end
    end

    def set_run_attribute(run, path, value, type, credentials = nil)
      # get the identifier from the run if that is what is passed in
      if run.instance_of? Run
        run = run.identifier
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

    def delete_run_attribute(run, path, credentials = nil)
      # get the identifier from the run if that is what is passed in
      if run.instance_of? Run
        run = run.identifier
      end

      delete_attribute("#{@links[:runs]}/#{run}/#{path}", credentials)
    rescue AttributeNotFoundError => e
      if get_runs(credentials).has_key? run
        raise e
      else
        raise RunNotFoundError.new(run)
      end
    end

    def download_run_file(run, path, range, credentials = nil)
      # get the identifier from the run if that is what is passed in
      if run.instance_of? Run
        run = run.identifier
      end

      get_attribute("#{@links[:runs]}/#{run}/#{path}",
        "application/octet-stream", range, credentials)
    rescue AttributeNotFoundError => e
      if get_runs(credentials).has_key? run
        raise e
      else
        raise RunNotFoundError.new(run)
      end
    end

    def get_admin_attribute(path, credentials = nil)
      get_attribute("#{@links[:admin]}/#{path}", "*/*", credentials)
    end

    def set_admin_attribute(path, value, credentials = nil)
      set_attribute("#{@links[:admin]}/#{path}", value, "text/plain",
        credentials)
    end

    def admin_resource_writable?(path, credentials = nil)
      headers = @connection.OPTIONS("#{@links[:admin]}/#{path}", credentials)
      headers["allow"][0].split(",").include? "PUT"
    end
    # :startdoc:

    private
    def create_attribute(path, value, type, credentials = nil)
      @connection.POST(path, value, type, credentials)
    end

    def get_attribute(path, type, *rest)
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
        @connection.GET(path, type, range, credentials)
      rescue ConnectionRedirectError => cre
        @connection = cre.redirect
        retry
      end
    end

    def set_attribute(path, value, type, credentials = nil)
      @connection.PUT(path, value, type, credentials)
    end

    def delete_attribute(path, credentials = nil)
      @connection.DELETE(path, credentials)
    end

    def get_version(doc)
      version = xpath_attr(doc, XPaths[:server], "serverVersion")
      if version == nil
        raise RuntimeError.new("Taverna Servers prior to version 2.3 " +
          "are no longer supported.")
      else
        return version.to_f
      end
    end

    def get_description(doc)
      links = {}
      links[:runs] = URI.parse(xpath_attr(doc, XPaths[:runs], "href")).path

      links[:policy] = URI.parse(xpath_attr(doc, XPaths[:policy], "href")).path
      doc = xml_document(get_attribute(links[:policy], "application/xml"))

      links[:permlisteners] =
        URI.parse(xpath_attr(doc, XPaths[:permlstt], "href")).path
      links[:notifications] =
        URI.parse(xpath_attr(doc, XPaths[:notify], "href")).path

      links[:runlimit]      =
        URI.parse(xpath_attr(doc, XPaths[:runlimit], "href")).path
      links[:permworkflows] =
        URI.parse(xpath_attr(doc, XPaths[:permwkf], "href")).path

      links
    end

    def get_runs(credentials = nil)
      run_list = get_attribute("#{@links[:runs]}", "application/xml",
        credentials)

      doc = xml_document(run_list)

      # get list of run identifiers
      ids = []
      xpath_find(doc, XPaths[:run]).each do |run|
        ids << xml_node_attribute(run, "href").split('/')[-1]
      end

      # cache run objects - this must be done per user
      user = credentials.nil? ? :all : credentials.username
      @runs[user] = {} unless @runs[user]

      # add new runs
      ids.each do |id|
        if !@runs[user].has_key? id
          @runs[user][id] = Run.create(self, "", credentials, id)
        end
      end

      # clear out the expired runs
      if @runs[user].length > ids.length
        @runs[user].delete_if {|key, val| !ids.member? key}
      end

      @runs[user]
    end
  end
end
