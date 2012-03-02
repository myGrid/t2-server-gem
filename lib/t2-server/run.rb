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

require 'rubygems'
require 'time'

module T2Server

  # An interface for easily running jobs on a Taverna 2 Server with minimal
  # setup and configuration required.
  #
  # A run can be in one of three states:
  # * :initialized - The run has been accepted by the server. It may not yet be
  #   ready to run though as its input port may not have been set.
  # * :running - The run is being run by the server.
  # * :finished - The run has finished running and its outputs are available for
  #   download.
  class Run
    include XML::Methods

    private_class_method :new

    # The identifier of this run on the server.
    attr_reader :identifier
    alias :id :identifier

    # The server instance that this run is hosted on.
    attr_reader :server

    # :stopdoc:
    XPaths = {
      # Run XPath queries
      :dir        => XML::Methods.xpath_compile("//nss:dir"),
      :file       => XML::Methods.xpath_compile("//nss:file"),
      :expiry     => XML::Methods.xpath_compile("//nsr:expiry"),
      :workflow   => XML::Methods.xpath_compile("//nsr:creationWorkflow"),
      :status     => XML::Methods.xpath_compile("//nsr:status"),
      :createtime => XML::Methods.xpath_compile("//nsr:createTime"),
      :starttime  => XML::Methods.xpath_compile("//nsr:startTime"),
      :finishtime => XML::Methods.xpath_compile("//nsr:finishTime"),
      :wdir       => XML::Methods.xpath_compile("//nsr:workingDirectory"),
      :inputs     => XML::Methods.xpath_compile("//nsr:inputs"),
      :output     => XML::Methods.xpath_compile("//nsr:output"),
      :securectx  => XML::Methods.xpath_compile("//nsr:securityContext"),
      :listeners  => XML::Methods.xpath_compile("//nsr:listeners"),
      :baclava    => XML::Methods.xpath_compile("//nsr:baclava"),
      :inputexp   => XML::Methods.xpath_compile("//nsr:expected"),

      # Port descriptions XPath queries
      :port_in    => XML::Methods.xpath_compile("//port:input"),
      :port_out   => XML::Methods.xpath_compile("//port:output")
    }

    # The name to be used internally for retrieving results via baclava
    BACLAVA_FILE = "out.xml"

    # New is private but rdoc does not get it right! Hence :stopdoc: section.
    def initialize(server, id, credentials = nil)
      @server = server
      @identifier = id
      @workflow = ""
      @baclava_in = false
      @baclava_out = false
      
      @credentials = credentials
      
      @links = get_attributes(@server.get_run_attribute(@identifier, "",
        "application/xml", @credentials))
      #@links.each {|key, val| puts "#{key}: #{val}"}
      
      # initialize ports lists to nil as an empty list means no inputs/outputs
      @input_ports = nil
      @output_ports = nil
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
    # created instance of T2Server::Server. The _workflow_ must also be
    # supplied as a string in t2flow or scufl format. User credentials and
    # connection parameters can be supplied if required but are both optional.
    # If _server_ is an instance of T2Server::Server then
    # _connection_parameters_ will be ignored.
    #
    # This method will _yield_ the newly created Run if a block is given.
    def Run.create(server, workflow, *rest)
      credentials = nil
      id = nil
      conn_params = nil

      rest.each do |param|
        case param
        when String
          id = param
        when ConnectionParameters
          conn_params = param
        when Credentials
          credentials = param
        end
      end

      if server.class != Server
        server = Server.new(server, conn_params)
      end
      
      if id.nil?
        id = server.initialize_run(workflow, credentials)
      end
      
      run = new(server, id, credentials)
      yield(run) if block_given?
      run
    end

    # :stopdoc:
    def uuid
      warn "[DEPRECATION] 'uuid' is deprecated and will be removed in 1.0. " +
        "Please use Run#id or Run#identifier instead."
      @identifier
    end
    # :startdoc:
    
    # :call-seq:
    #   delete
    #
    # Delete this run from the server.
    def delete
      @server.delete_run(@identifier, @credentials)
    end

    # :stopdoc:
    def inputs
      warn "[DEPRECATION] 'inputs' is deprecated and will be removed in 1.0."
      @links[:inputs]
    end

    def set_input(input, value)
      warn "[DEPRECATION] 'Run#set_input' is deprecated and will be removed " +
        "in 1.0. Input ports are set directly instead. The most direct " +
        "replacement for this method is: 'Run#input_port(input).value = value'"

      input_port(input).value = value
    end

    def set_input_file(input, filename)
      warn "[DEPRECATION] 'Run#set_input_file' is deprecated and will be " +
        "removed in 1.0. Input ports are set directly instead. The most " +
        "direct replacement for this method is: " +
        "'Run#input_port(input).remote_file = filename'"

      input_port(input).remote_file = filename
    end
    # :startdoc:

    # :call-seq:
    #   input_ports -> Hash
    #
    # Return a hash (name, port) of all the input ports this run expects.
    def input_ports
      @input_ports = _get_input_port_info if @input_ports.nil?

      @input_ports
    end

    # :call-seq:
    #   input_port(port) -> Port
    #
    # Get _port_.
    def input_port(port)
      input_ports[port]
    end

    # :call-seq:
    #   output_ports -> Hash
    #
    # Return a hash (name, port) of all the output ports this run has. Until
    # the run is finished this method will return _nil_.
    def output_ports
      if finished? and @output_ports.nil?
        @output_ports = _get_output_port_info
      end

      @output_ports
    end

    # :call-seq:
    #   output_port(port) -> Port
    #
    # Get output port _port_.
    def output_port(port)
      output_ports[port] if finished?
    end

    # :stopdoc:
    def get_output_ports
      warn "[DEPRECATION] 'get_output_ports' is deprecated and will be " +
        "removed in 1.0. Please use 'Run#output_ports' instead."
      lists, items = _ls_ports("out")
      items + lists
    end

    def get_output(output, refs=false)
      warn "[DEPRECATION] 'get_output' is deprecated and will be removed " +
        "in 1.0. Please use 'Run#output_port(port).values' instead."
      _get_output(output, refs)
    end

    def get_output_refs(output)
      warn "[DEPRECATION] 'get_output_refs' is deprecated and will be " +
        "removed in 1.0. Please use 'Run#output_port(port).data' instead."
      _get_output(output, true)
    end
    # :startdoc:

    # :call-seq:
    #   expiry -> string
    #
    # Return the expiry time of this run as an instance of class Time.
    def expiry
      Time.parse(@server.get_run_attribute(@identifier, @links[:expiry],
        "text/plain", @credentials))
    end

    # :call-seq:
    #   expiry=(time) -> bool
    #
    # Set the expiry time of this run to _time_. _time_ should either be a Time
    # object or something that the Time class can parse. If the value given does
    # not specify a date then today's date will be assumed. If a time/date in
    # the past is specified, the expiry time will not be changed.
    def expiry=(time)
      unless time.instance_of? Time
        time = Time.parse(time)
      end

      # need to massage the xmlschema format slightly as the server cannot
      # parse timezone offsets with a colon (eg +00:00)
      date_str = time.xmlschema(2)
      date_str = date_str[0..-4] + date_str[-2..-1]
      @server.set_run_attribute(@identifier, @links[:expiry], date_str,
        "text/plain", @credentials)
    end

    # :call-seq:
    #   workflow -> string
    #
    # Get the workflow that this run represents.
    def workflow
      if @workflow == ""
        @workflow = @server.get_run_attribute(@identifier, @links[:workflow],
          "application/xml", @credentials)
      end
      @workflow
    end

    # :call-seq:
    #   status -> string
    #
    # Get the status of this run. Status can be one of :initialized,
    # :running or :finished.
    def status
      text_to_state(@server.get_run_attribute(@identifier, @links[:status],
        "text/plain", @credentials))
    end

    # :call-seq:
    #   start
    #
    # Start this run on the server.
    #
    # Raises RunStateError if the run is not in the :initialized state.
    def start
      state = status
      raise RunStateError.new(state, :initialized) if state != :initialized

      # set all the inputs
      _set_all_inputs unless baclava_input?

      @server.set_run_attribute(@identifier, @links[:status],
        state_to_text(:running), "text/plain", @credentials)
    end

    # :call-seq:
    #   wait(check_interval = 1)
    #
    # Wait (block) for this run to finish. How often (in seconds) the run is
    # tested for completion can be specified with check_interval.
    #
    # Raises RunStateError if the run is still in the :initialised state.
    def wait(*params)
      state = status
      raise RunStateError.new(state, :running) if state == :initialized

      interval = 1
      params.each do |param|
        case param
        when Hash
          warn "[DEPRECATION] 'Run#wait(params={})' is deprecated and will " +
            "be removed in 1.0. Please use Run#wait(check_interval) instead."
          interval = param[:interval] || 1
        when Integer
          interval = param
        end
      end

      # wait
      until finished?
        sleep(interval)
      end
    end

    # :call-seq:
    #   exitcode -> integer
    #
    # Get the return code of the run. Zero indicates success.
    def exitcode
      @server.get_run_attribute(@identifier, @links[:exitcode], "text/plain",
        @credentials).to_i
    end

    # :call-seq:
    #   stdout -> string
    #
    # Get anything that the run printed to the standard out stream.
    def stdout
      @server.get_run_attribute(@identifier, @links[:stdout], "text/plain",
        @credentials)
    end

    # :call-seq:
    #   stderr -> string
    #
    # Get anything that the run printed to the standard error stream.
    def stderr
      @server.get_run_attribute(@identifier, @links[:stderr], "text/plain",
        @credentials)
    end

    # :call-seq:
    #   mkdir(dir) -> bool
    #
    # Create a directory in the run's working directory on the server. This
    # could be used to store input data.
    def mkdir(dir)
      dir = Util.strip_path_slashes(dir)
      if dir.include? ?/
        # if a path is given then separate the leaf from the
        # end and add the rest of the path to the wdir link
        leaf = dir.split("/")[-1]
        path = dir[0...-(leaf.length + 1)]
        @server.create_dir(@identifier, "#{@links[:wdir]}/#{path}", leaf,
          @credentials)
      else
        @server.create_dir(@identifier, @links[:wdir], dir, @credentials)
      end
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
      location = "#{@links[:wdir]}/#{location}"
      rename = params[:rename] || ""
      @server.upload_file(@identifier, filename, location, rename, @credentials)
    end

    # :stopdoc:
    def upload_input_file(input, filename, params={})
      warn "[DEPRECATION] 'Run#upload_input_file' is deprecated and will be " +
        "removed in 1.0. Input ports are set directly instead. The most " +
        "direct replacement for this method is: " +
        "'Run#input_port(input).file = filename'"

      input_port(input).file = filename
    end
    # :startdoc:

    # :call-seq:
    #   baclava_input=(filename) -> bool
    #
    # Use a baclava file for the workflow inputs.
    def baclava_input=(filename)
      state = status
      raise RunStateError.new(state, :initialized) if state != :initialized

      rename = upload_file(filename)
      result = @server.set_run_attribute(@identifier, @links[:baclava], rename,
        "text/plain", @credentials)

      @baclava_in = true if result

      result        
    end

    # :stopdoc:
    def upload_baclava_input(filename)
      warn "[DEPRECATION] 'upload_baclava_input' is deprecated and will be " +
        "removed in 1.0. Please use 'Run#baclava_input=' instead."
      self.baclava_input = filename
    end

    def upload_baclava_file(filename)
      warn "[DEPRECATION] 'upload_baclava_file' is deprecated and will be " +
        "removed in 1.0. Please use 'Run#baclava_input=' instead."
      self.baclava_input = filename
    end
    # :startdoc:

    # :call-seq:
    #   request_baclava_output -> bool
    #
    # Set the server to save the outputs of this run in baclava format. This
    # must be done before the run is started.
    def request_baclava_output
      return if @baclava_out
      state = status
      raise RunStateError.new(state, :initialized) if state != :initialized
      
      @baclava_out = @server.set_run_attribute(@identifier, @links[:output],
        BACLAVA_FILE, "text/plain", @credentials)
    end

    # :stopdoc:
    def set_baclava_output(name="")
      warn "[DEPRECATION] 'set_baclava_output' is deprecated and will be removed in 1.0. " +
        "Please use 'Run#request_baclava_output' instead."
      self.request_baclava_output
    end
    # :startdoc:

    # :call-seq:
    #   baclava_input? -> bool
    #
    # Have the inputs to this run been set by a baclava document?
    def baclava_input?
      @baclava_in
    end

    # :call-seq:
    #   baclava_output? -> bool
    #
    # Has this run been set to return results in baclava format?
    def baclava_output?
      @baclava_out
    end

    # :call-seq:
    #   baclava_output -> string
    #
    # Get the outputs of this run in baclava format. This can only be done if
    # the output has been requested in baclava format by #set_baclava_output
    # before starting the run.
    def baclava_output
      state = status
      raise RunStateError.new(state, :finished) if state != :finished
      
      raise AccessForbiddenError.new("baclava output") if !@baclava_out
      @server.get_run_attribute(@identifier, "#{@links[:wdir]}/#{BACLAVA_FILE}",
        "*/*", @credentials)
    end

    # :stopdoc:
    def get_baclava_output
      warn "[DEPRECATION] 'get_baclava_output' is deprecated and will be removed in 1.0. " +
              "Please use 'Run#baclava_output' instead."
      baclava_output
    end
    # :startdoc:

    # :call-seq:
    #   zip_output -> binary blob
    #
    # Get the working directory of this run directly from the server in zip
    # format.
    def zip_output
      state = status
      raise RunStateError.new(state, :finished) if state != :finished

      @server.get_run_attribute(@identifier, "#{@links[:wdir]}/out",
        "application/zip", @credentials)
    end

    # :call-seq:
    #   initialized? -> bool
    #
    # Is this run in the :initialized state?
    def initialized?
      status == :initialized
    end

    # :call-seq:
    #   running? -> bool
    #
    # Is this run in the :running state?
    def running?
      status == :running
    end

    # :call-seq:
    #   finished? -> bool
    #
    # Is this run in the :finished state?
    def finished?
      status == :finished
    end

    # :call-seq:
    #   create_time -> string
    #
    # Get the creation time of this run as an instance of class Time.
    def create_time
      Time.parse(@server.get_run_attribute(@identifier, @links[:createtime],
        "text/plain", @credentials))
    end

    # :call-seq:
    #   start_time -> string
    #
    # Get the start time of this run as an instance of class Time.
    def start_time
      Time.parse(@server.get_run_attribute(@identifier, @links[:starttime],
        "text/plain", @credentials))
    end

    # :call-seq:
    #   finish_time -> string
    #
    # Get the finish time of this run as an instance of class Time.
    def finish_time
      Time.parse(@server.get_run_attribute(@identifier, @links[:finishtime],
        "text/plain", @credentials))
    end

    # :stopdoc:
    # Outputs are represented as a directory structure with the eventual list
    # items (leaves) as files. This method (not part of the public API)
    # downloads a file from the run's working directory.
    def download_output_data(path, range = nil)
      @server.download_run_file(@identifier, "#{@links[:wdir]}/out/#{path}",
        range, @credentials)
    end
    # :startdoc:

    private

    # Set all the inputs on the server. The inputs must have been set prior to
    # this call using the InputPort API.
    def _set_all_inputs
      input_ports.each_value do |port|
        next unless port.set?

        if port.file?
          # If we're using a local file upload it first then set the port to
          # use a remote file.
          unless port.remote_file?
            file = upload_file(port.file)
            port.remote_file = file
          end

          xml_value = xml_text_node(port.file)
          path = "#{@links[:inputs]}/input/#{port.name}"
          @server.set_run_attribute(self, path,
            XML::Fragments::RUNINPUTFILE % xml_value, "application/xml",
            @credentials)
        else
          xml_value = xml_text_node(port.value)
          path = "#{@links[:inputs]}/input/#{port.name}"
          @server.set_run_attribute(self, path,
            XML::Fragments::RUNINPUTVALUE % xml_value, "application/xml",
            @credentials)
        end
      end
    end

    # List a directory in the run's workspace on the server. If dir is left
    # blank then / is listed. As there is no concept of changing into a
    # directory (cd) in Taverna Server then all paths passed into _ls_ports
    # should be full paths starting at "root". The contents of a directory are
    # returned as a list of two lists, "lists" and "values" respectively.
    def _ls_ports(dir="", top=true)
      dir = Util.strip_path_slashes(dir)
      dir_list = @server.get_run_attribute(@identifier,
        "#{@links[:wdir]}/#{dir}", "*/*", @credentials)

      # compile a list of directory entries stripping the
      # directory name from the front of each filename
      lists = []
      values = []

      doc = xml_document(dir_list)

      xpath_find(doc, XPaths[:dir]).each do |e|
        if top
          lists << xml_node_content(e).split('/')[-1]
        else
          index = (xml_node_attribute(e, 'name').to_i - 1)
          lists[index] = xml_node_content(e).split('/')[-1]
        end
      end

      xpath_find(doc, XPaths[:file]).each do |e|
        if top
          values << xml_node_content(e).split('/')[-1]
        else
          index = (xml_node_attribute(e, 'name').to_i - 1)
          values[index] = xml_node_content(e).split('/')[-1]
        end
      end

      [lists, values]
    end

    def _get_output(output, refs=false, top=true)
      output = Util.strip_path_slashes(output)

      # if at the top level we need to check if the port represents a list
      # or a singleton value
      if top
        lists, items = _ls_ports("out")
        if items.include? output
          if refs
            return "#{@server.uri}/rest/runs/#{@identifier}/#{@links[:wdir]}/out/#{output}"
          else
            return @server.get_run_attribute(@identifier,
              "#{@links[:wdir]}/out/#{output}", "application/octet-stream",
              @credentials)
          end
        end
      end

      # we're not at the top level so look at the contents of the output port
      lists, items = _ls_ports("out/#{output}", false)

      # build up lists of results
      result = []

      # for each list recurse into it and add the items to the result
      lists.each {|list| result << _get_output("#{output}/#{list}", refs, false)}

      # for each item, add it to the output list
      items.each do |item|
        if refs
          result << "#{@server.uri}/rest/runs/#{@identifier}/#{@links[:wdir]}/out/#{output}/#{item}"
        else
          result << @server.get_run_attribute(@identifier,
            "#{@links[:wdir]}/out/#{output}/#{item}", "application/octet-stream",
            @credentials)
        end
      end

      result
    end

    def _get_input_port_info
      return {} if @server.version < 2
        ports = {}
        port_desc = @server.get_run_attribute(@identifier, @links[:inputexp],
          "application/xml", @credentials)

        doc = xml_document(port_desc)

        xpath_find(doc, XPaths[:port_in]).each do |inp|
          port = InputPort.new(self, inp)
          ports[port.name] = port
        end

      ports
    end

    def _get_output_port_info
      return {} if @server.version < 2

      ports = {}
      port_desc = @server.get_run_attribute(@identifier, @links[:output],
        "application/xml", @credentials)

      doc = xml_document(port_desc)

      xpath_find(doc, XPaths[:port_out]).each do |out|
        #puts out.to_s
        port = OutputPort.new(self, out)
        ports[port.name] = port
      end

      ports
    end

    def get_attributes(desc)
      # first parse out the basic stuff
      links = {}

      doc = xml_document(desc)
      
      [:expiry, :workflow, :status, :createtime, :starttime, :finishtime,
        :wdir, :inputs, :output, :securectx, :listeners].each do |key|
          links[key] = xpath_attr(doc, XPaths[key], "href").split('/')[-1]
      end

      # get inputs
      inputs = @server.get_run_attribute(@identifier, links[:inputs],
        "application/xml",@credentials)
      doc = xml_document(inputs)

      links[:baclava] = "#{links[:inputs]}/" + xpath_attr(doc, XPaths[:baclava], "href").split('/')[-1]
      if @server.version > 1
        links[:inputexp] = "#{links[:inputs]}/" + xpath_attr(doc, XPaths[:inputexp], "href").split('/')[-1]
      end

      # set io properties
      links[:io]       = "#{links[:listeners]}/io"
      links[:stdout]   = "#{links[:io]}/properties/stdout"
      links[:stderr]   = "#{links[:io]}/properties/stderr"
      links[:exitcode] = "#{links[:io]}/properties/exitcode"
      
      links
    end

    # :stopdoc:
    STATE2TEXT = {
      :initialized => "Initialized",
      :running     => "Operating",
      :finished    => "Finished",
      :stopped     => "Stopped"
    }

    TEXT2STATE = {
      "Initialized" => :initialized,
      "Operating"   => :running,
      "Finished"    => :finished,
      "Stopped"     => :stopped
    }
    # :startdoc:

    def state_to_text(state)
      STATE2TEXT[state.to_sym]
    end

    def text_to_state(text)
      TEXT2STATE[text]
    end
  end
end
