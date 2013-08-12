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
require 'time'
require 'rubygems'
require 'taverna-baclava'

module T2Server

  # An interface for easily running jobs on a Taverna 2 Server with minimal
  # setup and configuration required.
  #
  # A run can be in one of three states:
  # * :initialized - The run has been accepted by the server. It may not yet be
  #   ready to run though as its input port may not have been set.
  # * :running - The run is being run by the server.
  # * :finished - The run has finished running and its outputs are available
  #   for download.
  class Run
    include XML::Methods

    private_class_method :new

    # The identifier of this run on the server.
    attr_reader :identifier
    alias :id :identifier

    # The server instance that this run is hosted on.
    attr_reader :server

    # :stopdoc:
    XPATHS = {
      # Run XPath queries
      :run_desc   => "/nsr:runDescription",
      :dir        => "//nss:dir",
      :file       => "//nss:file",
      :expiry     => "//nsr:expiry",
      :workflow   => "//nsr:creationWorkflow",
      :status     => "//nsr:status",
      :createtime => "//nsr:createTime",
      :starttime  => "//nsr:startTime",
      :finishtime => "//nsr:finishTime",
      :wdir       => "//nsr:workingDirectory",
      :inputs     => "//nsr:inputs",
      :output     => "//nsr:output",
      :securectx  => "//nsr:securityContext",
      :listeners  => "//nsr:listeners",
      :baclava    => "//nsr:baclava",
      :inputexp   => "//nsr:expected",
      :name       => "//nsr:name",
      :intfeed    => "//nsr:interaction",

      # Port descriptions XPath queries
      :port_in    => "//port:input",
      :port_out   => "//port:output",

      # Run security XPath queries
      :sec_creds  => "//nsr:credentials",
      :sec_perms  => "//nsr:permissions",
      :sec_trusts => "//nsr:trusts",
      :sec_perm   => "/nsr:permissionsDescriptor/nsr:permission",
      :sec_uname  => "nsr:userName",
      :sec_uperm  => "nsr:permission",
      :sec_cred   => "/nsr:credential",
      :sec_suri   => "nss:serviceURI",
      :sec_trust  => "/nsr:trustedIdentities/nsr:trust"
    }

    @@xpaths = XML::XPathCache.instance
    @@xpaths.register_xpaths XPATHS

    # The name to be used internally for retrieving results via baclava
    BACLAVA_FILE = "out.xml"

    # New is private but rdoc does not get it right! Hence :stopdoc: section.
    def initialize(server, uri, credentials = nil)
      @server = server
      @uri = uri
      @identifier = Util.get_path_leaf_from_uri(@uri)
      @workflow = ""
      @baclava_in = false
      @baclava_out = false

      @credentials = credentials

      # Has this Run object been deleted from the server?
      @deleted = false

      # The following three fields hold cached data about the run that is only
      # downloaded the first time it is requested.
      @run_doc = nil
      @owner = nil
      @links = nil

      # initialize ports lists to nil as an empty list means no inputs/outputs
      @input_ports = nil
      @output_ports = nil

      # The interaction reader to use for this run, if required.
      @interaction_reader = nil
    end
    # :startdoc:

    # :call-seq:
    #   Run.create(server, workflow) -> run
    #   Run.create(server, workflow, connection_parameters) -> run
    #   Run.create(server, workflow, user_credentials) -> run
    #   Run.create(server, workflow, ...) {|run| ...}
    #
    # Create a new run in the :initialized state. The run will be created on
    # the server with address supplied by _server_. This can either be a
    # String of the form <tt>http://example.com:8888/blah</tt> or an already
    # created instance of T2Server::Server. The _workflow_ may be supplied
    # as a string in t2flow format, a filename or a File or IO object. User
    # credentials and connection parameters can be supplied if required but
    # are both optional. If _server_ is an instance of T2Server::Server then
    # _connection_parameters_ will be ignored.
    #
    # This method will _yield_ the newly created Run if a block is given.
    def Run.create(server, workflow, *rest)
      credentials = nil
      uri = nil
      conn_params = nil

      rest.each do |param|
        case param
        when URI
          uri = param
        when ConnectionParameters
          conn_params = param
        when HttpCredentials
          credentials = param
        end
      end

      # If server is not a Server object, get one.
      server = Server.new(server, conn_params) if server.class != Server

      # If we are not given a URI to a run then we know we need to create one.
      uri ||= server.initialize_run(workflow, credentials)

      # Create the run object and yield it if necessary.
      run = new(server, uri, credentials)
      yield(run) if block_given?
      run
    end

    # :call-seq:
    #   owner -> string
    #
    # Get the username of the owner of this run. The owner is the user who
    # created the run on the server.
    def owner
      @owner ||= _get_run_owner
    end

    # :call-seq:
    #   name -> String
    #
    # Get the name of this run.
    #
    # Initially this name is derived by Taverna Server from the name
    # annotation in the workflow file and the time at which the run was
    # initialized. It can be set with the <tt>name=</tt> method.
    #
    # For Taverna Server versions prior to version 2.5.0 this is a no-op and
    # the empty string is returned for consistency.
    def name
      return "" if links[:name].nil?
      @server.read(links[:name], "text/plain", @credentials)
    end

    # :call-seq:
    #   name = new_name -> bool
    #
    # Set the name of this run. +true+ is returned upon success. The maximum
    # length of names supported by the server is 48 characters. Anything
    # longer than 48 characters will be truncated before upload.
    #
    # Initially this name is derived by Taverna Server from the name
    # annotation in the workflow file and the time at which the run was
    # initialized.
    #
    # For Taverna Server versions prior to version 2.5.0 this is a no-op but
    # +true+ is still returned for consistency.
    def name=(name)
      return true if links[:name].nil?
      @server.update(links[:name], name[0...48], "text/plain", @credentials)
    end

    # :call-seq:
    #   delete
    #
    # Delete this run from the server.
    def delete
      @server.delete(@uri, @credentials)
      @deleted = true
    end

    # :call-seq:
    #   deleted? -> true or false
    #
    # Has this run been deleted from the server?
    def deleted?
      @deleted
    end

    # :call-seq:
    #   input_ports -> hash
    #
    # Return a hash (name, port) of all the input ports this run expects.
    def input_ports
      @input_ports ||= _get_input_port_info
    end

    # :call-seq:
    #   input_port(port) -> port
    #
    # Get _port_.
    def input_port(port)
      input_ports[port]
    end

    # :call-seq:
    #   output_ports -> hash
    #
    # Return a hash (name, port) of all the output ports this run has. Until
    # the run is finished this method will return _nil_.
    def output_ports
      if finished? && @output_ports.nil?
        @output_ports = _get_output_port_info
      end

      @output_ports
    end

    # :call-seq:
    #   output_port(port) -> port
    #
    # Get output port _port_.
    def output_port(port)
      output_ports[port] if finished?
    end

    # :call-seq:
    #   expiry -> string
    #
    # Return the expiry time of this run as an instance of class Time.
    def expiry
      Time.parse(@server.read(links[:expiry], "text/plain", @credentials))
    end

    # :call-seq:
    #   expiry = time -> true or false
    #
    # Set the expiry time of this run to _time_. _time_ should either be a Time
    # object or something that the Time class can parse. If the value given
    # does not specify a date then today's date will be assumed. If a time/date
    # in the past is specified, the expiry time will not be changed.
    def expiry=(time)
      unless time.instance_of? Time
        time = Time.parse(time)
      end

      # need to massage the xmlschema format slightly as the server cannot
      # parse timezone offsets with a colon (eg +00:00)
      date_str = time.xmlschema(2)
      date_str = date_str[0..-4] + date_str[-2..-1]
      @server.update(links[:expiry], date_str, "text/plain", @credentials)
    end

    # :call-seq:
    #   workflow -> string
    #
    # Get the workflow that this run represents.
    def workflow
      if @workflow == ""
        @workflow = @server.read(links[:workflow], "application/xml",
          @credentials)
      end
      @workflow
    end

    # :call-seq:
    #   status -> string
    #
    # Get the status of this run. Status can be one of :initialized,
    # :running or :finished.
    def status
      return :deleted if @deleted
      Status.to_sym(@server.read(links[:status], "text/plain", @credentials))
    end

    # :call-seq:
    #   start -> true or false
    #
    # Start this run on the server. Returns true if the run was started, false
    # otherwise.
    #
    # Raises RunStateError if the run is not in the :initialized state.
    def start
      state = status
      raise RunStateError.new(state, :initialized) if state != :initialized

      # set all the inputs
      _check_and_set_inputs unless baclava_input?

      begin
        @server.update(links[:status], Status.to_text(:running), "text/plain",
          @credentials)
      rescue ServerAtCapacityError => sace
        false
      end
    end

    # :call-seq:
    #   wait(check_interval = 1)
    #
    # Wait (block) for this run to finish. How often (in seconds) the run is
    # tested for completion can be specified with check_interval.
    #
    # Raises RunStateError if the run is still in the :initialised state.
    def wait(interval = 1)
      state = status
      raise RunStateError.new(state, :running) if state == :initialized

      # wait
      until finished?
        sleep(interval)
      end
    end

    # :call-seq:
    #   exitcode -> fixnum
    #
    # Get the return code of the run. Zero indicates success.
    def exitcode
      @server.read(links[:exitcode], "text/plain", @credentials).to_i
    end

    # :call-seq:
    #   stdout -> string
    #
    # Get anything that the run printed to the standard out stream.
    def stdout
      @server.read(links[:stdout], "text/plain", @credentials)
    end

    # :call-seq:
    #   stderr -> string
    #
    # Get anything that the run printed to the standard error stream.
    def stderr
      @server.read(links[:stderr], "text/plain", @credentials)
    end

    # :call-seq:
    #   log -> string
    #   log(filename) -> fixnum
    #   log(stream) -> fixnum
    #   log {|chunk| ...}
    #
    # Get the internal Taverna Server log from this run.
    #
    # Calling this method with no parameters will simply return a text string.
    # Providing a filename will stream the data directly to that file and
    # return the number of bytes written. Passing in an object that has a
    # +write+ method (for example, an instance of File or IO) will stream the
    # text directly to that object and return the number of bytes that were
    # streamed. Passing in a block will allow access to the underlying data
    # stream:
    #   run.log do |chunk|
    #     print chunk
    #   end
    def log(param = nil, &block)
      raise ArgumentError,
        'both a parameter and block given for baclava_output' if param && block

      download_or_stream(param, links[:logfile], "text/plain", &block)
    end

    # :call-seq:
    #   mkdir(dir) -> true or false
    #
    # Create a directory in the run's working directory on the server. This
    # could be used to store input data.
    def mkdir(dir)
      dir = Util.strip_path_slashes(dir)

      @server.mkdir(links[:wdir], dir, @credentials)
    end

    # :call-seq:
    #   upload_file(filename, params={}) -> string
    #
    # Upload a file, with name _filename_, to the server. Possible values that
    # can be passed in via _params_ are:
    # * :dir - The directory to upload to. If this is not left blank the
    #   corresponding directory will need to have been created by Run#mkdir.
    # * :rename - Save the file on the server with a different name.
    #
    # The name of the file on the server is returned.
    def upload_file(filename, params={})
      location = params[:dir] || ""
      uri = Util.append_to_uri_path(links[:wdir], location)
      rename = params[:rename] || ""
      file_uri = @server.upload_file(filename, uri, rename, @credentials)
      Util.get_path_leaf_from_uri(file_uri)
    end

    # :call-seq:
    #   upload_data(data, remote_name, remote_directory = "") -> true or false
    #
    # Upload data to the server and store it in <tt>remote_file</tt>. The
    # remote directory to put this file in can also be specified, but if it is
    # it must first have been created by a call to Run#mkdir.
    def upload_data(data, remote_name, remote_directory = "")
      location_uri = Util.append_to_uri_path(links[:wdir], remote_directory)
      @server.upload_data(data, remote_name, location_uri, @credentials)
    end

    # :call-seq:
    #   baclava_input = filename -> true or false
    #
    # Use a baclava file for the workflow inputs.
    def baclava_input=(filename)
      state = status
      raise RunStateError.new(state, :initialized) if state != :initialized

      file = upload_file(filename)
      result = @server.update(links[:baclava], file, "text/plain", @credentials)

      @baclava_in = true if result

      result
    end

    # :call-seq:
    #   request_baclava_output -> true or false
    #
    # Set the server to save the outputs of this run in baclava format. This
    # must be done before the run is started.
    def request_baclava_output
      return if @baclava_out
      state = status
      raise RunStateError.new(state, :initialized) if state != :initialized

      @baclava_out = @server.update(links[:output], BACLAVA_FILE, "text/plain",
        @credentials)
    end

    # :call-seq:
    #   baclava_input? -> true or false
    #
    # Have the inputs to this run been set by a baclava document?
    def baclava_input?
      @baclava_in
    end

    # :call-seq:
    #   baclava_output? -> true or false
    #
    # Has this run been set to return results in baclava format?
    def baclava_output?
      @baclava_out
    end

    # :call-seq:
    #   baclava_output -> string
    #   baclava_output(filename) -> fixnum
    #   baclava_output(stream) -> fixnum
    #   baclava_output {|chunk| ...}
    #
    # Get the outputs of this run in baclava format. This can only be done if
    # the output has been requested in baclava format by #set_baclava_output
    # before starting the run.
    #
    # Calling this method with no parameters will simply return a blob of
    # XML data. Providing a filename will stream the data directly to that
    # file and return the number of bytes written. Passing in an object that
    # has a +write+ method (for example, an instance of File or IO) will
    # stream the XML data directly to that object and return the number of
    # bytes that were streamed. Passing in a block will allow access to the
    # underlying data stream:
    #   run.baclava_output do |chunk|
    #     print chunk
    #   end
    #
    # Raises RunStateError if the run has not finished running.
    def baclava_output(param = nil, &block)
      raise ArgumentError,
        'both a parameter and block given for baclava_output' if param && block

      state = status
      raise RunStateError.new(state, :finished) if state != :finished

      raise AccessForbiddenError.new("baclava output") if !@baclava_out

      baclava_uri = Util.append_to_uri_path(links[:wdir], BACLAVA_FILE)
      download_or_stream(param, baclava_uri, "*/*", &block)
    end

    # :call-seq:
    #   zip_output -> binary blob
    #   zip_output(filename) -> fixnum
    #   zip_output(stream) -> fixnum
    #   zip_output {|chunk| ...}
    #
    # Get the working directory of this run directly from the server in zip
    # format.
    #
    # Calling this method with no parameters will simply return a blob of
    # zipped data. Providing a filename will stream the data directly to that
    # file and return the number of bytes written. Passing in an object that
    # has a +write+ method (for example, an instance of File or IO) will
    # stream the zip data directly to that object and return the number of
    # bytes that were streamed. Passing in a block will allow access to the
    # underlying data stream:
    #   run.zip_output do |chunk|
    #     print chunk
    #   end
    #
    # Raises RunStateError if the run has not finished running.
    def zip_output(param = nil, port = "", &block)
      raise ArgumentError,
        "both a parameter and block given for zip_output" if param && block

      state = status
      raise RunStateError.new(state, :finished) if state != :finished

      path = port.empty? ? "out" : "out/#{port}"
      output_uri = Util.append_to_uri_path(links[:wdir], path)
      download_or_stream(param, output_uri, "application/zip", &block)
    end

    # :call-seq:
    #   initialized? -> true or false
    #
    # Is this run in the :initialized state?
    def initialized?
      status == :initialized
    end

    # :call-seq:
    #   running? -> true or false
    #
    # Is this run in the :running state?
    def running?
      status == :running
    end

    # :call-seq:
    #   finished? -> true or false
    #
    # Is this run in the :finished state?
    def finished?
      status == :finished
    end

    # :call-seq:
    #   error? -> true or false
    #
    # Are there errors in this run's outputs? Returns false if the run is not
    # finished yet.
    def error?
      return false unless finished?

      output_ports.values.each do |output|
        return true if output.error?
      end

      false
    end

    # :call-seq:
    #   create_time -> string
    #
    # Get the creation time of this run as an instance of class Time.
    def create_time
      Time.parse(@server.read(links[:createtime], "text/plain", @credentials))
    end

    # :call-seq:
    #   start_time -> string
    #
    # Get the start time of this run as an instance of class Time.
    def start_time
      Time.parse(@server.read(links[:starttime], "text/plain", @credentials))
    end

    # :call-seq:
    #   finish_time -> string
    #
    # Get the finish time of this run as an instance of class Time.
    def finish_time
      Time.parse(@server.read(links[:finishtime], "text/plain", @credentials))
    end

    # :call-seq:
    #   owner? -> true or false
    #
    # Are the credentials being used to access this run those of the owner?
    # The owner of the run can give other users certain access rights to their
    # runs but only the owner can change these rights - or even see what they
    # are. Sometimes it is useful to know if the user accessing the run is
    # actually the owner of it or not.
    def owner?
      @credentials.username == owner
    end

    # :call-seq:
    #   grant_permission(username, permission) -> username
    #
    # Grant the user the stated permission. A permission can be one of
    # <tt>:none</tt>, <tt>:read</tt>, <tt>:update</tt> or <tt>:destroy</tt>.
    # Only the owner of a run may grant permissions on it. +nil+ is returned
    # if a user other than the owner uses this method.
    def grant_permission(username, permission)
      return unless owner?

      value = XML::Fragments::PERM_UPDATE % [username, permission.to_s]
      @server.create(links[:sec_perms], value, "application/xml", @credentials)
    end

    # :call-seq:
    #   permissions -> hash
    #
    # Return a hash (username => permission) of all the permissions set for
    # this run. Only the owner of a run may query its permissions. +nil+ is
    # returned if a user other than the owner uses this method.
    def permissions
      return unless owner?

      perms = {}
      doc = xml_document(@server.read(links[:sec_perms], "application/xml",
        @credentials))

      xpath_find(doc, @@xpaths[:sec_perm]).each do |p|
        user = xml_node_content(xpath_first(p, @@xpaths[:sec_uname]))
        perm = xml_node_content(xpath_first(p, @@xpaths[:sec_uperm])).to_sym
        perms[user] = perm
      end

      perms
    end

    # :call-seq:
    #   permission(username) -> permission
    #
    # Return the permission granted to the supplied username, if any. Only the
    # owner of a run may query its permissions. +nil+ is returned if a user
    # other than the owner uses this method.
    def permission(username)
      return unless owner?

      permissions[username] || :none
    end

    # :call-seq:
    #   revoke_permission(username) -> true or false
    #
    # Revoke whatever permissions that have been granted to the user. Only the
    # owner of a run may revoke permissions on it. +nil+ is returned if a user
    # other than the owner uses this method.
    def revoke_permission(username)
      return unless owner?

      uri = Util.append_to_uri_path(links[:sec_perms], username)
      @server.delete(uri, @credentials)
    end

    # :call-seq:
    #   add_password_credential(service_uri, username, password) -> URI
    #
    # Provide a username and password credential for the secure service at the
    # specified URI. The URI of the credential on the server is returned. Only
    # the owner of a run may supply credentials for it. +nil+ is returned if a
    # user other than the owner uses this method.
    def add_password_credential(uri, username, password)
      return unless owner?

      # Is this a new credential, or an update?
      cred_uri = credential(uri)

      # basic uri checks
      uri = _check_cred_uri(uri)

      cred = XML::Fragments::USERPASS_CRED % [uri, username, password]
      value = XML::Fragments::CREDENTIAL % cred

      if cred_uri.nil?
        @server.create(links[:sec_creds], value, "application/xml",
          @credentials)
      else
        @server.update(cred_uri, value, "application/xml", @credentials)
      end
    end

    # :call-seq:
    #   add_keypair_credential(service_uri, filename, password,
    #     alias = "Imported Certificate", type = :pkcs12) -> URI
    #
    # Provide a client certificate credential for the secure service at the
    # specified URI. You will need to provide the password to unlock the
    # private key. You will also need to provide the 'alias' or 'friendlyName'
    # of the key you wish to use if it differs from the default. The URI of the
    # credential on the server is returned. Only the owner of a run may supply
    # credentials for it. +nil+ is returned if a user other than the owner uses
    # this method.
    def add_keypair_credential(uri, filename, password,
                               name = "Imported Certificate", type = :pkcs12)
      return unless owner?

      type = type.to_s.upcase
      contents = Base64.encode64(IO.read(filename))

      # basic uri checks
      uri = _check_cred_uri(uri)

      cred = XML::Fragments::KEYPAIR_CRED % [uri, name, contents,
        type, password]
      value = XML::Fragments::CREDENTIAL % cred

      @server.create(links[:sec_creds], value, "application/xml", @credentials)
    end

    # :call-seq:
    #   credentials -> hash
    #
    # Return a hash (service_uri => credential_uri) of all the credentials
    # provided for this run. Only the owner of a run may query its credentials.
    # +nil+ is returned if a user other than the owner uses this method.
    def credentials
      return unless owner?

      creds = {}
      doc = xml_document(@server.read(links[:sec_creds], "application/xml",
        @credentials))

      xpath_find(doc, @@xpaths[:sec_cred]).each do |c|
        uri = URI.parse(xml_node_content(xpath_first(c, @@xpaths[:sec_suri])))
        cred_uri = URI.parse(xml_node_attribute(c, "href"))
        creds[uri] = cred_uri
      end

      creds
    end

    # :call-seq:
    #   credential(service_uri) -> URI
    #
    # Return the URI of the credential set for the supplied service, if
    # any. Only the owner of a run may query its credentials. +nil+ is
    # returned if a user other than the owner uses this method.
    def credential(uri)
      return unless owner?

      credentials[uri]
    end

    # :call-seq:
    #   delete_credential(service_uri) -> true or false
    #
    # Delete the credential that has been provided for the specified service.
    # Only the owner of a run may delete its credentials. +nil+ is returned if
    # a user other than the owner uses this method.
    def delete_credential(uri)
      return unless owner?

      @server.delete(credentials[uri], @credentials)
    end

    # :call-seq:
    #   delete_all_credentials -> true or false
    #
    # Delete all credentials associated with this workflow run. Only the owner
    # of a run may delete its credentials. +nil+ is returned if a user other
    # than the owner uses this method.
    def delete_all_credentials
      return unless owner?

      @server.delete(links[:sec_creds], @credentials)
    end

    # :call-seq:
    #   add_trust(filename, type = :x509) -> URI
    #
    # Add a trusted identity (server public key) to verify peers when using
    # https connections to Web Services. The URI of the trust on the server is
    # returned. Only the owner of a run may add a trust. +nil+ is returned if
    # a user other than the owner uses this method.
    def add_trust(filename, type = :x509)
      return unless owner?

      type = type.to_s.upcase

      contents = Base64.encode64(IO.read(filename))

      value = XML::Fragments::TRUST % [contents, type]
      @server.create(links[:sec_trusts], value, "application/xml", @credentials)
    end

    # :call-seq:
    #   trusts -> array
    #
    # Return a list of all the URIs of trusts that have been registered for
    # this run. At present there is no way to differentiate between trusts
    # without noting the URI returned when originally uploaded. Only the owner
    # of a run may query its trusts. +nil+ is returned if a user other than the
    # owner uses this method.
    def trusts
      return unless owner?

      t_uris = []
      doc = xml_document(@server.read(links[:sec_trusts], "application/xml",
        @credentials))

      xpath_find(doc, @@xpaths[:sec_trust]). each do |t|
        t_uris << URI.parse(xml_node_attribute(t, "href"))
      end

      t_uris
    end

    # :call-seq:
    #   delete_trust(URI) -> true or false
    #
    # Delete the trust with the provided URI. Only the owner of a run may
    # delete its trusts. +nil+ is returned if a user other than the owner uses
    # this method.
    def delete_trust(uri)
      return unless owner?

      @server.delete(uri, @credentials)
    end

    # :call-seq:
    #   delete_all_trusts -> true or false
    #
    # Delete all trusted identities associated with this workflow run. Only
    # the owner of a run may delete its trusts. +nil+ is returned if a user
    # other than the owner uses this method.
    def delete_all_trusts
      return unless owner?

      @server.delete(links[:sec_trusts], @credentials)
    end

    # :stopdoc:
    # Outputs are represented as a directory structure with the eventual list
    # items (leaves) as files. This method (not part of the public API)
    # downloads a file from the run's working directory.
    def download_output_data(uri, range = nil, &block)
      @server.read(uri, "application/octet-stream", range, @credentials,
        &block)
    end

    def interaction_feed
      @server.read(links[:intfeed], "application/atom+xml", @credentials)
    end

    # This is a slightly unpleasant hack to help proxy notification
    # communications through a third party.
    def notifications_uri
      links[:intfeed] || ""
    end

    # This is a slightly unpleasant hack to help proxy interaction
    # communications through a third party.
    def interactions_uri
      links[:intdir] || ""
    end
    # :startdoc:

    # :call-seq:
    #   notifications(type = :new_requests) -> array
    #
    # Poll the server for notifications and return them in a list. Returns the
    # empty list if there are none, or if the server does not support the
    # Interaction Service.
    #
    # The +type+ parameter is used to select which types of notifications are
    # returned as follows:
    # * <tt>:requests</tt> - Interaction requests.
    # * <tt>:replies</tt> - Interaction replies.
    # * <tt>:new_requests</tt> - Interaction requests that are new since the
    #   last time they were polled (default).
    # * <tt>:all</tt> - All interaction requests and replies.
    def notifications(type = :new_requests)
      return [] if links[:intfeed].nil?

      @interaction_reader ||= Interaction::Feed.new(self)

      if type == :new_requests
        @interaction_reader.new_requests
      else
        @interaction_reader.notifications(type)
      end
    end

    private

    def links
      @links ||= _get_run_links
    end

    # Check each input to see if it requires a list input and call the
    # requisite upload method for the entire set of inputs.
    def _check_and_set_inputs
      lists = false
      input_ports.each_value do |port|
        if port.depth > 0
          lists = true
          break
        end
      end

      lists ? _fake_lists : _set_all_inputs
    end

    # Set all the inputs on the server. The inputs must have been set prior to
    # this call using the InputPort API.
    def _set_all_inputs
      input_ports.each_value do |port|
        next unless port.set?

        uri = Util.append_to_uri_path(links[:inputs], "input/#{port.name}")
        if port.file?
          # If we're using a local file upload it first then set the port to
          # use a remote file.
          port.remote_file = upload_file(port.file) unless port.remote_file?

          xml_value = XML::Fragments::RUNINPUTFILE % xml_text_node(port.file)
        else
          xml_value = XML::Fragments::RUNINPUTVALUE % xml_text_node(port.value)
        end

        @server.update(uri, xml_value, "application/xml", @credentials)
      end
    end

    # Fake being able to handle lists as inputs by converting everything into
    # one big baclava document and uploading that. This has to be done for all
    # inputs or none at all. The inputs must have been set prior to this call
    # using the InputPort API.
    def _fake_lists
      data_map = {}

      input_ports.each_value do |port|
        next unless port.set?

        if port.file?
          unless port.remote_file?
            file = File.read(port.file)
            data_map[port.name] = Taverna::Baclava::Node.new(file)
          end
        else
          data_map[port.name] = Taverna::Baclava::Node.new(port.value)
        end
      end

      # Create and upload the baclava data.
      baclava = Taverna::Baclava::Writer.write(data_map)
      upload_data(baclava, "in.baclava")
      @server.update(links[:baclava], "in.baclava", "text/plain", @credentials)
    end

    # Check that the uri passed in is suitable for credential use:
    #  * rserve uris must not have a path.
    #  * http(s) uris must have at least "/" as their path.
    def _check_cred_uri(uri)
      u = URI(uri)

      case u.scheme
      when "rserve"
        u.path = ""
      when /https?/
        u.path = "/" if u.path == ""
      end

      u.to_s
    end

    def _get_input_port_info
      ports = {}
      port_desc = @server.read(links[:inputexp], "application/xml",
        @credentials)

      doc = xml_document(port_desc)

      xpath_find(doc, @@xpaths[:port_in]).each do |inp|
        port = InputPort.new(self, inp)
        ports[port.name] = port
      end

      ports
    end

    def _get_output_port_info
      ports = {}

      begin
        port_desc = @server.read(links[:output], "application/xml", @credentials)
      rescue AttributeNotFoundError => anfe
        return ports
      end

      doc = xml_document(port_desc)

      xpath_find(doc, @@xpaths[:port_out]).each do |out|
        port = OutputPort.new(self, out)
        ports[port.name] = port
      end

      ports
    end

    def _get_run_description
      if @run_doc.nil?
        @run_doc = xml_document(@server.read(@uri, "application/xml",
          @credentials))
      end

      @run_doc
    end

    def _get_run_owner
      doc = _get_run_description

      xpath_attr(doc, @@xpaths[:run_desc], "owner")
    end

    def _get_run_links
      doc = _get_run_description

      # first parse out the basic stuff
      links = get_uris_from_doc(doc, [:expiry, :workflow, :status,
        :createtime, :starttime, :finishtime, :wdir, :inputs, :output,
        :securectx, :listeners, :name, :intfeed])

      # Working dir links
      _get_wdir_links(links)

      # get inputs
      inputs = @server.read(links[:inputs], "application/xml",@credentials)
      doc = xml_document(inputs)

      links.merge! get_uris_from_doc(doc, [:baclava, :inputexp])

      # set io properties
      links[:io]       = Util.append_to_uri_path(links[:listeners], "io")
      [:stdout, :stderr, :exitcode].each do |res|
        links[res] = Util.append_to_uri_path(links[:io], "properties/#{res}")
      end

      # security properties - only available to the owner of a run
      if owner?
        securectx = @server.read(links[:securectx], "application/xml",
          @credentials)
        doc = xml_document(securectx)

        links.merge! get_uris_from_doc(doc,
          [:sec_creds, :sec_perms, :sec_trusts])
      end

      links
    end

    def _get_wdir_links(links)
      # Logs directory
      links[:logdir] = Util.append_to_uri_path(links[:wdir], "logs")

      # Log file
      links[:logfile] = Util.append_to_uri_path(links[:logdir], "detail.log")

      # Interaction working directory, if we have a feed.
      unless links[:intfeed].nil?
        links[:intdir] = Util.append_to_uri_path(links[:wdir], "interactions")
      end
    end

    def download_or_stream(param, uri, type, &block)
      if param.respond_to? :write
        @server.read_to_stream(param, uri, type, @credentials)
      elsif param.instance_of? String
        @server.read_to_file(param, uri, type, @credentials)
      else
        @server.read(uri, type, @credentials, &block)
      end
    end

    # :stopdoc:
    class Status
      STATE2TEXT = {
        :initialized => "Initialized",
        :running     => "Operating",
        :finished    => "Finished",
        :stopped     => "Stopped",
        :deleted     => "Deleted"
      }

      TEXT2STATE = {
        "Initialized" => :initialized,
        "Operating"   => :running,
        "Finished"    => :finished,
        "Stopped"     => :stopped
      }

      def Status.to_text(state)
        STATE2TEXT[state.to_sym]
      end

      def Status.to_sym(text)
        TEXT2STATE[text]
      end
    end
    # :startdoc:

  end
end
