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
require 'libxml'
require 'time'

module T2Server

  # An interface for easily running jobs on a Taverna 2 Server with minimal
  # setup and configuration required.
  #
  # A run can be in one of three states:
  # * Initialized: The run has been accepted by the server. It may not yet be
  #   ready to run though as its input port may not have been set.
  # * Running: The run is being run by the server.
  # * Finished: The run has finished running and its outputs are available for
  #   download.
  class Run
    include LibXML

    private_class_method :new

    # The identifier of this run on the server. It is currently a UUID
    # (version 4).
    attr_reader :uuid

    # The server instance that this run is hosted on.
    attr_reader :server

    # :stopdoc:
    STATE = {
      :initialized => "Initialized",
      :running     => "Operating",
      :finished    => "Finished",
      :stopped     => "Stopped"
    }

    # The name to be used internally for retrieving results via baclava
    BACLAVA_FILE = "out.xml"

    # New is private but rdoc does not get it right! Hence :stopdoc: section.
    def initialize(server, uuid, credentials = nil)
      @server = server
      @uuid = uuid
      @workflow = ""
      @baclava_in = false
      @baclava_out = false
      
      @credentials = credentials
      
      @links = get_attributes(@server.get_run_attribute(uuid, "", @credentials))
      #@links.each {|key, val| puts "#{key}: #{val}"}
      
      # initialize @input_ports to nil as an empty list means no inputs
      @input_ports = nil
    end
    # :startdoc:

    # :call-seq:
    #   Run.create(server, workflow, credentials = nil) -> run
    #
    # Create a new run in the +Initialized+ state. The run will be created on
    # the server with address supplied by _server_. This can either be a
    # String of the form <tt>http://example.com:8888/blah</tt> or an already
    # created instance of T2Server::Server. The _workflow_ must also be
    # supplied as a string in t2flow or scufl format.
    def Run.create(server, workflow, credentials = nil, uuid="")
      if server.class != Server
        server = Server.new(server)
      end
      
      if uuid == ""
        uuid = server.initialize_run(workflow, credentials)
      end
      
      new(server, uuid, credentials)
    end

    # :call-seq:
    #   run.delete
    #
    # Delete this run from the server.
    def delete
      @server.delete_run(uuid, @credentials)
    end

    # :call-seq:
    #   run.inputs -> string
    #
    # Return the path to the input ports of this run on the server.
    def inputs
      @links[:inputs]
    end

    # :call-seq:
    #   run.set_input(input, value) -> bool
    #
    # Set the workflow input port _input_ to _value_.
    #
    # Raises RunStateError if the run is not in the +Initialized+ state.
    def set_input(input, value)
      state = status
      raise RunStateError.new(state, STATE[:initialized]) if state != STATE[:initialized]

      @server.set_run_input(self, input, value, @credentials)
    end

    # :call-seq:
    #   run.set_input_file(input, filename) -> bool
    #
    # Set the workflow input port _input_ to use the file at _filename_ as its
    # input data.
    #
    # Raises RunStateError if the run is not in the +Initialized+ state.
    def set_input_file(input, filename)
      state = status
      raise RunStateError.new(state, STATE[:initialized]) if state != STATE[:initialized]

      @server.set_run_input_file(self, input, filename, @credentials)
    end

    # :call-seq:
    #   run.input_ports -> array
    #
    # Return the names of all the input ports this run expects
    def input_ports
      _get_input_port_info.keys
    end

    # :call-seq:
    #   input_port_depth(port) -> integer
    #
    # Get the depth of _port_.
    def input_port_depth(port)
      _get_input_port_info[port].depth
    end

    # :call-seq:
    #   run.get_output_ports -> list
    #
    # Return a list of all the output ports
    def get_output_ports
      lists, items = _ls_ports("out")
      items + lists
    end

    # :call-seq:
    #   run.get_output(output, refs=false) -> string or list
    #
    # Return the values of the workflow output port _output_. These are
    # returned as a list of strings or, if the output port represents a
    # singleton value, then a string returned. By default this method returns
    # the actual data from the output port but if _refs_ is set to true then
    # it will instead return URIs to the actual data in the same list format.
    # See also Run#get_output_refs.
    def get_output(output, refs=false)
      _get_output(output, refs)
    end

    # :call-seq:
    #   run.get_output_refs(output) -> string or list
    #
    # Return references (URIs) to the values of the workflow output port
    # _output_. These are returned as a list of URIs or, if the output port
    # represents a singleton value, then a single URI is returned. The URIs
    # are returned as strings.
    def get_output_refs(output)
      _get_output(output, true)
    end

    # :call-seq:
    #   run.expiry -> string
    #
    # Return the expiry time of this run as an instance of class Time.
    def expiry
      Time.parse(@server.get_run_attribute(@uuid, @links[:expiry],
        @credentials))
    end

    # :call-seq:
    #   run.expiry=(time) -> bool
    #
    # Set the expiry time of this run to _time_. The format of _time_ should
    # be something that the Ruby Time class can parse. If the value given does
    # not specify a date then today's date will be assumed. If a time/date in
    # the past is specified, the expiry time will not be changed.
    def expiry=(time)
      # need to massage the xmlschema format slightly as the server cannot
      # parse timezone offsets with a colon (eg +00:00)
      date_str = Time.parse(time).xmlschema(2)
      date_str = date_str[0..-4] + date_str[-2..-1]
      @server.set_run_attribute(@uuid, @links[:expiry], date_str, @credentials)
    end

    # :call-seq:
    #   run.workflow -> string
    #
    # Get the workflow that this run represents.
    def workflow
      if @workflow == ""
        @workflow = @server.get_run_attribute(@uuid, @links[:workflow],
          @credentials)
      end
      @workflow
    end

    # :call-seq:
    #   run.status -> string
    #
    # Get the status of this run.
    def status
      @server.get_run_attribute(@uuid, @links[:status], @credentials)
    end

    # :call-seq:
    #   run.start
    #
    # Start this run on the server.
    #
    # Raises RunStateError if the run is not in the +Initialized+ state.
    def start
      state = status
      raise RunStateError.new(state, STATE[:initialized]) if state != STATE[:initialized]

      @server.set_run_attribute(@uuid, @links[:status], STATE[:running],
        @credentials)
    end

    # :call-seq:
    #   run.wait(params={})
    #
    # Wait (block) for this run to finish. Possible values that can be passed
    # in via _params_ are:
    # * :interval - How often (in seconds) to test for run completion.
    #   Default +1+.
    # * :progress - Print a dot (.) each interval to show that something is
    #   actually happening. Default +false+.
    #
    # Raises RunStateError if the run is not in the +Running+ state.
    def wait(params={})
      state = status
      raise RunStateError.new(state, STATE[:running]) if state != STATE[:running]

      interval = params[:interval] || 1
      progress = params[:progress] || false
      keepalive = params[:keepalive] || false ### TODO maybe move out of params
      
      # wait
      until finished?
        sleep(interval)
        if progress
          print "."
          STDOUT.flush
        end
      end
      
      # tidy up output if there is any
      puts if progress
    end

    # :call-seq:
    #   run.exitcode -> integer
    #
    # Get the return code of the run. Zero indicates success.
    def exitcode
      @server.get_run_attribute(@uuid, @links[:exitcode], @credentials).to_i
    end

    # :call-seq:
    #   run.stdout -> string
    #
    # Get anything that the run printed to the standard out stream.
    def stdout
      @server.get_run_attribute(@uuid, @links[:stdout], @credentials)
    end

    # :call-seq:
    #   run.stderr -> string
    #
    # Get anything that the run printed to the standard error stream.
    def stderr
      @server.get_run_attribute(@uuid, @links[:stderr], @credentials)
    end

    # :call-seq:
    #   run.mkdir(dir) -> bool
    #
    # Create a directory in the run's working directory on the server. This
    # could be used to store input data.
    def mkdir(dir)
      dir.strip_path!
      if dir.include? ?/
        # if a path is given then separate the leaf from the
        # end and add the rest of the path to the wdir link
        leaf = dir.split("/")[-1]
        path = dir[0...-(leaf.length + 1)]
        @server.make_run_dir(@uuid, "#{@links[:wdir]}/#{path}", leaf,
          @credentials)
      else
        @server.make_run_dir(@uuid, @links[:wdir], dir, @credentials)
      end
    end

    # :call-seq:
    #   run.upload_file(filename, params={}) -> string
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
      @server.upload_run_file(@uuid, filename, location, rename, @credentials)
    end

    # :call-seq:
    #   run.upload_input_file(input, filename, params={}) -> string
    #
    # Upload a file, with name _filename_, to the server and set it as the
    # input data for input port _input_. Possible values that can be passed
    # in via _params_ are:
    # * :dir - The directory to upload to. If this is not left blank the
    #   corresponding directory will need to have been created by Run#mkdir.
    # * :rename - Save the file on the server with a different name.
    #
    # The name of the file on the server is returned.
    #
    # Raises RunStateError if the run is not in the +Initialized+ state.
    def upload_input_file(input, filename, params={})
      state = status
      raise RunStateError.new(state, STATE[:initialized]) if state != STATE[:initialized]

      file = upload_file(filename, params)
      set_input_file(input, file)
    end

    # :call-seq:
    #   run.upload_baclava_file(filename) -> bool
    #
    # Upload a baclava file to be used for the workflow inputs.
    def upload_baclava_file(filename)
      state = status
      raise RunStateError.new(state, STATE[:initialized]) if state != STATE[:initialized]

      @baclava_in = true
      rename = upload_file(filename)
      @server.set_run_attribute(@uuid, @links[:baclava], rename, @credentials)
    end

    # :call-seq:
    #   run.request_baclava_output -> bool
    #
    # Set the server to save the outputs of this run in baclava format. This
    # must be done before the run is started.
    def request_baclava_output
      return if @baclava_out
      state = status
      raise RunStateError.new(state, STATE[:initialized]) if state != STATE[:initialized]
      
      @baclava_out = @server.set_run_attribute(@uuid, @links[:output],
        BACLAVA_FILE, @credentials)
    end

    # :stopdoc:
    def set_baclava_output(name="")
      warn "[DEPRECATION] 'set_baclava_output' is deprecated and will be removed in 1.0. " +
        "Please use 'Run#request_baclava_output' instead."
      self.request_baclava_output
    end
    # :startdoc:

    # :call-seq:
    #   run.baclava_output? -> bool
    #
    # Has this run been set to return results in baclava format?
    def baclava_output?
      @baclava_out
    end

    # :call-seq:
    #   run.baclava_output -> string
    #
    # Get the outputs of this run in baclava format. This can only be done if
    # the output has been requested in baclava format by #set_baclava_output
    # before starting the run.
    def baclava_output
      state = status
      raise RunStateError.new(state, STATE[:finished]) if state != STATE[:finished]
      
      raise AccessForbiddenError.new("baclava output") if !@baclava_out
      @server.get_run_attribute(@uuid, "#{@links[:wdir]}/#{BACLAVA_FILE}",
        @credentials)
    end

    # :stopdoc:
    def get_baclava_output
      warn "[DEPRECATION] 'get_baclava_output' is deprecated and will be removed in 1.0. " +
              "Please use 'Run#baclava_output' instead."
      baclava_output
    end
    # :startdoc:

    # :call-seq:
    #   run.initialized? -> bool
    #
    # Is this run in the +Initialized+ state?
    def initialized?
      status == STATE[:initialized]
    end

    # :call-seq:
    #   run.running? -> bool
    #
    # Is this run in the +Running+ state?
    def running?
      status == STATE[:running]
    end

    # :call-seq:
    #   run.finished? -> bool
    #
    # Is this run in the +Finished+ state?
    def finished?
      status == STATE[:finished]
    end

    # :call-seq:
    #   run.create_time -> string
    #
    # Get the creation time of this run as an instance of class Time.
    def create_time
      Time.parse(@server.get_run_attribute(@uuid, @links[:createtime],
        @credentials))
    end

    # :call-seq:
    #   run.start_time -> string
    #
    # Get the start time of this run as an instance of class Time.
    def start_time
      Time.parse(@server.get_run_attribute(@uuid, @links[:starttime],
        @credentials))
    end

    # :call-seq:
    #   run.finish_time -> string
    #
    # Get the finish time of this run as an instance of class Time.
    def finish_time
      Time.parse(@server.get_run_attribute(@uuid, @links[:finishtime],
        @credentials))
    end

    private

    # List a directory in the run's workspace on the server. If dir is left
    # blank then / is listed. As there is no concept of changing into a
    # directory (cd) in Taverna Server then all paths passed into _ls_ports
    # should be full paths starting at "root". The contents of a directory are
    # returned as a list of two lists, "lists" and "values" respectively.
    def _ls_ports(dir="", top=true)
      dir.strip_path!
      dir_list = @server.get_run_attribute(@uuid, "#{@links[:wdir]}/#{dir}",
        @credentials)

      # compile a list of directory entries stripping the
      # directory name from the front of each filename
      lists = []
      values = []

      begin
        doc = XML::Document.string(dir_list)

        doc.find(XPaths::DIR, Namespaces::MAP).each do |e|
          if top
            lists << e.content.split('/')[-1]
          else
            index = (e.attributes['name'].to_i - 1)
            lists[index] = e.content.split('/')[-1]
          end
        end

        doc.find(XPaths::FILE, Namespaces::MAP).each do |e|
          if top
            values << e.content.split('/')[-1]
          else
            index = (e.attributes['name'].to_i - 1)
            values[index] = e.content.split('/')[-1]
          end
        end
      rescue XML::Error => xmle
        # We expect to get a DOCUMENT_EMPTY error in some cases. All others
        # should be re-raised.
        if xmle.code != XML::Error::DOCUMENT_EMPTY
          raise xmle
        end
      end

      [lists, values]
    end

    def _get_output(output, refs=false, top=true)
      output.strip_path!

      # if at the top level we need to check if the port represents a list
      # or a singleton value
      if top
        lists, items = _ls_ports("out")
        if items.include? output
          if refs
            return "#{@server.uri}/rest/runs/#{@uuid}/#{@links[:wdir]}/out/#{output}"
          else
            return @server.get_run_attribute(@uuid,
              "#{@links[:wdir]}/out/#{output}", @credentials)
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
          result << "#{@server.uri}/rest/runs/#{@uuid}/#{@links[:wdir]}/out/#{output}/#{item}"
        else
          result << @server.get_run_attribute(@uuid,
            "#{@links[:wdir]}/out/#{output}/#{item}", @credentials)
        end
      end

      result
    end

    def _get_input_port_info
      @input_ports = {} if @server.version < 2
      if @input_ports == nil
        @input_ports = {}
        port_desc = @server.get_run_attribute(@uuid, @links[:inputexp], @credentials)

        doc = XML::Document.string(port_desc)
        nsmap = Namespaces::MAP

        doc.find(XPaths::INP_INPUT, nsmap).each do |inp|
          name = inp.find_first(XPaths::INP_NAME, nsmap).content
          depth = inp.find_first(XPaths::INP_DEPTH, nsmap).content.to_i
          @input_ports[name] = Port.new(name, depth)
        end
      end

      @input_ports
    end

    def get_attributes(desc)
      # first parse out the basic stuff
      links = parse_description(desc)
      
      # get inputs
      inputs = @server.get_run_attribute(@uuid, links[:inputs], @credentials)
      doc = XML::Document.string(inputs)
      nsmap = Namespaces::MAP
      links[:baclava] = "#{links[:inputs]}/" + doc.find_first(XPaths::BACLAVA, nsmap).attributes["href"].split('/')[-1]
      if @server.version > 1
        links[:inputexp] = "#{links[:inputs]}/" + doc.find_first(XPaths::INPUTSEXP, nsmap).attributes["href"].split('/')[-1]
      end

      # set io properties
      links[:io]       = "#{links[:listeners]}/io"
      links[:stdout]   = "#{links[:io]}/properties/stdout"
      links[:stderr]   = "#{links[:io]}/properties/stderr"
      links[:exitcode] = "#{links[:io]}/properties/exitcode"
      
      links
    end

    def parse_description(desc)
      doc = XML::Document.string(desc)
      nsmap = Namespaces::MAP
      {
        :expiry     => doc.find_first(XPaths::EXPIRY, nsmap).attributes["href"].split('/')[-1],
        :workflow   => doc.find_first(XPaths::WORKFLOW, nsmap).attributes["href"].split('/')[-1],
        :status     => doc.find_first(XPaths::STATUS, nsmap).attributes["href"].split('/')[-1],
        :createtime => doc.find_first(XPaths::CREATETIME, nsmap).attributes["href"].split('/')[-1],
        :starttime  => doc.find_first(XPaths::STARTTIME, nsmap).attributes["href"].split('/')[-1],
        :finishtime => doc.find_first(XPaths::FINISHTIME, nsmap).attributes["href"].split('/')[-1],
        :wdir       => doc.find_first(XPaths::WDIR, nsmap).attributes["href"].split('/')[-1],
        :inputs     => doc.find_first(XPaths::INPUTS, nsmap).attributes["href"].split('/')[-1],
        :output     => doc.find_first(XPaths::OUTPUT, nsmap).attributes["href"].split('/')[-1],
        :securectx  => doc.find_first(XPaths::SECURECTX, nsmap).attributes["href"].split('/')[-1],
        :listeners  => doc.find_first(XPaths::LISTENERS, nsmap).attributes["href"].split('/')[-1]
      }
    end

    # This is a private class for internal use only. It is used to represent
    # an input/output port of a workflow
    class Port
      
      # The port's name
      attr_reader :name
      
      # The "depth" of the port. 0 = a singleton value.
      attr_reader :depth

      # Create a new port with an optional depth.
      def initialize(name, depth = 0)
        @name = name
        @depth = depth
      end
    end

  end
end
