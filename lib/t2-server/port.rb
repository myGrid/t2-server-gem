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

module T2Server

  # Base class of InputPort and OutputPort
  class Port
    include XML::Methods

    # The port's name
    attr_reader :name

    # The "depth" of the port. 0 = a singleton value.
    attr_reader :depth

    # :stopdoc:
    # Create a new port.
    def initialize(run, xml)
      @run = run

      parse_xml(xml)
    end
    # :startdoc:

    private
    def parse_xml(xml)
      @name = xml_node_attribute(xml, 'name')
      @depth = xml_node_attribute(xml, 'depth').to_i
    end
  end

  # Represents an input to a workflow.
  class InputPort < Port

    # If set, the file which has been used to supply this port's data.
    attr_reader :file

    # If set, the value held by this port. Could be a list (of lists (etc)).
    attr_reader :value

    # :stopdoc:
    # Create a new InputPort.
    def initialize(run, xml)
      super(run, xml)

      @value = nil
      @file = nil
      @remote_file = false
    end
    # :startdoc:

    # :call-seq:
    #   value = value
    #
    # Set the value of this input port. This has no effect if the run is
    # already running or finished.
    def value=(value)
      return unless @run.initialized?
      @file = nil
      @remote_file = false
      @value = value
    end

    # :call-seq:
    #   file? -> bool
    #
    # Is this port's data being supplied by a file? The file could be local or
    # remote (already on the server) for this to return true.
    def file?
      !@file.nil?
    end

    # :call-seq:
    #   remote_file? -> bool
    #
    # Is this port's data being supplied by a remote (one that is already on
    # the server) file?
    def remote_file?
      file? && @remote_file
    end

    # :call-seq:
    #   remote_file = filename
    #
    # Set the remote file to use for this port's data. The file must already be
    # on the server. This has no effect if the run is already running or
    # finished.
    def remote_file=(filename)
      return unless @run.initialized?
      @value = nil
      @file = filename
      @remote_file = true
    end

    # :call-seq:
    #   file = filename
    #
    # Set the file to use for this port's data. The file will be uploaded to
    # the server before the run starts. This has no effect if the run is
    # already running or finished.
    def file=(filename)
      return unless @run.initialized?
      @value = nil
      @file = filename
      @remote_file = false
    end

    # :call-seq:
    #   baclava? -> bool
    #
    # Has this port been set via a baclava document?
    def baclava?
      @run.baclava_input?
    end

    # :call-seq:
    #   set? -> bool
    #
    # Has this port been set?
    def set?
      !value.nil? || file? || baclava?
    end
  end

  # Represents an output port of a workflow.
  class OutputPort < Port
    include XML::Methods

    # :stopdoc:
    # Create a new OutputPort.
    def initialize(run, xml)
      super(run, xml)

      @error = false
      @structure = parse_data(xml_first_child(xml))

      # cached outputs
      @values = nil
      @refs = nil
      @types = nil
      @sizes = nil
      @total_size = nil
    end
    # :startdoc:

    # :call-seq:
    #   error? -> bool
    #
    # Is there an error associated with this output port?
    def error?
      @error
    end

    # :call-seq:
    #   empty? -> bool
    #
    # Is this output port empty?
    #
    # Note that if the output port holds a list then it is not considered
    # empty, even if that list is empty. This is because the port itself is
    # not empty, there is a list there! A separate test should be performed to
    # see if that list is empty or not.
    def empty?
      # Funnily enough, an empty list does *not* make a port empty!
      return false if @structure.instance_of? Array
      @structure.empty?
    end

    # :call-seq:
    #   [int] -> obj
    #
    # This call provides access to the underlying structure of the OutputPort.
    # It can only be used for ports of depth >= 1. For singleton ports, use
    # OutputPort#value instead.
    #
    # Example usage - To get part of a value from an output port with depth 3:
    # port[1][0][1].value(10...100)
    def [](i)
      return @structure if depth == 0
      @structure[i]
    end

    # :call-seq:
    #   value -> binary blob
    #   value(range) -> binary blob
    #   value {|chunk| ...}
    #   value(range) {|chunk| ...}
    #   value -> Array
    #
    # For singleton outputs download or stream the data (or part of it) held
    # by the output port. Please see the documentation for PortValue#value for
    # full details.
    #
    # For list outputs all data values are downloaded into memory and returned
    # in an Array structure that mirrors the structure of the output port. Do
    # not use this form if the output port has large amounts of data! To get
    # part of a value from a list use something like:
    #   run.output_port("port_name")[0].value(0..100)
    def value(range = nil, &block)
      if depth == 0
        if range.nil?
          @structure.value(&block)
        else
          @structure.value(range, &block)
        end
      else
        @values = strip(:value) if @values.nil?
        @values
      end
    end

    # :call-seq:
    #   stream_value(stream) -> Fixnum
    #   stream_value(stream, range) -> Fixnum
    #
    # Stream a singleton port value directly to another stream and return the
    # number of bytes written. If a range is supplied then only that range of
    # data is streamed from the server. The stream passed in may be anything
    # that provides a +write+ method; instances of IO and File, for example.
    # No data is cached by this method.
    #
    # To stream parts of a list port, use PortValue#stream_value on the list
    # item directly:
    #   run.output_port("port_name")[0].stream_value(stream)
    def stream_value(stream, range = nil)
      return 0 unless depth == 0
      raise ArgumentError,
        "Stream passed in must provide a write method" unless
          stream.respond_to? :write

      if range.nil?
        @structure.stream_value(stream)
      else
        @structure.stream_value(stream, range)
      end
    end

    # :call-seq:
    #   write_value_to_file(filename) -> Fixnum
    #   write_value_to_file(filename, range) -> Fixnum
    #
    # Stream a singleton port value to a file and return the number of bytes
    # written. If a range is supplied then only that range of data is
    # downloaded from the server.
    #
    # To save parts of a list port to a file, use
    # PortValue#write_value_to_file on the list item directly:
    #   run.output_port("port_name")[0].write_value_to_file
    def write_value_to_file(filename, range = nil)
      return 0 unless depth == 0

      if range.nil?
        @structure.write_value_to_file(filename)
      else
        @structure.write_value_to_file(filename, range)
      end
    end

    # :call-seq:
    #   reference -> String
    #   reference -> Array
    #
    # Get URI references to the data values of this output port as strings.
    #
    # For a singleton output a single uri is returned. For lists an array of
    # uris is returned. For an individual reference from a list use
    # 'port[].reference'.
    def reference
      @refs ||= strip(:reference)
    end

    # :call-seq:
    #   type -> String
    #   type -> Array
    #
    # Get the mime type of the data value in this output port.
    #
    # For a singleton output a single type is returned. For lists an array of
    # types is returned. For an individual type from a list use 'port[].type'.
    def type
      @types ||= strip(:type)
    end

    # :call-seq:
    #   size -> int
    #   size -> Array
    #
    # Get the data size of the data value in this output port.
    #
    # For a singleton output a single size is returned. For lists an array of
    # sizes is returned. For an individual size from a list use 'port[].size'.
    def size
      @sizes ||= strip(:size)
    end

    # :stopdoc:
    def error
      warn "[DEPRECATION] Using #error to get the error message is " +
      "deprecated and will be removed in version 2.0.0. Please use #value " +
      "instead."
      return nil unless depth == 0
      @structure.value
    end
    # :startdoc:

    # :call-seq:
    #   total_size -> int
    #
    # Return the total data size of all the data in this output port.
    def total_size
      return @total_size if @total_size
      if @structure.instance_of? Array
        return 0 if @structure.empty?
        @total_size = strip(:size).flatten.inject { |sum, i| sum + i }
      else
        @total_size = size
      end
    end

    # :call-seq:
    #   zip -> binary blob
    #   zip(filename) -> Fixnum
    #   zip(stream) -> Fixnum
    #   zip {|chunk| ...}
    #
    # Get the data in this output port directly from the server in zip format.
    #
    # This method does not work with singleton ports. Taverna Server cannot
    # currently return zip files of singleton ports on their own. If you wish
    # to get a singleton port in a zip file then you can use Run#zip_output
    # which will return all outputs in a single file.
    #
    # If this method is called on a singleton port it will return 0. Streaming
    # from it will return nothing.
    #
    # Calling this method with no parameters will simply return a blob of
    # zipped data. Providing a filename will stream the data directly to that
    # file and return the number of bytes written. Passing in an object that
    # has a +write+ method (for example, an instance of File or IO) will
    # stream the zip data directly to that object and return the number of
    # bytes that were streamed. Passing in a block will allow access to the
    # underlying data stream:
    #   port.zip do |chunk|
    #     print chunk
    #   end
    #
    # Raises RunStateError if the run has not finished running.
    def zip(param = nil, &block)
      return 0 if depth == 0
      @run.zip_output(param, name, &block)
    end

    # :stopdoc:
    def download(uri, range = nil, &block)
      @run.download_output_data(uri, range, &block)
    end
    # :startdoc:

    private

    # Parse the XML port description into a raw data value structure.
    def parse_data(node)
      case xml_node_name(node)
      when 'list'
        data = []
        xml_children(node) do |child|
          data << parse_data(child)
        end
        return data
      when 'value'
        return PortValue.new(self, xml_node_attribute(node, 'href'), false,
          xml_node_attribute(node, 'contentByteLength').to_i,
          xml_node_attribute(node, 'contentType'))
      when 'error'
        @error = true
        return PortValue.new(self, xml_node_attribute(node, 'href'), true,
          xml_node_attribute(node, 'errorByteLength').to_i)
      end
    end

    # Generate the path to the actual data for a data value.
    def path(ref)
      parts = ref.split('/')
      @depth == 0 ? parts[-1] : "/" + parts[-(@depth + 1)..-1].join('/')
    end

    # Strip the requested attribute from the raw values structure.
    def strip(attribute, struct = @structure)
      if struct.instance_of? Array
        data = []
        struct.each { |item| data << strip(attribute, item) }
        return data
      else
        struct.method(attribute).call
      end
    end
  end

  # A class to represent an output port data value.
  class PortValue

    # The URI reference of this port value as a String.
    attr_reader :reference

    # The mime type of this port value as a String.
    attr_reader :type

    # The size (in bytes) of the port value.
    attr_reader :size

    # The mime-type we use for an error value.
    ERROR_TYPE = "application/x-error"

    # The mime-type we use for an empty value. Note that an empty value is not
    # simply an empty string. It is the complete absence of a value.
    EMPTY_TYPE = "application/x-empty"

    # :stopdoc:
    def initialize(port, ref, error, size, type = "")
      @port = port
      @reference = URI.parse(ref)
      @type = (error ? ERROR_TYPE : type)
      @size = size
      @value = nil
      @vgot = nil
      @error = error
    end
    # :startdoc:

    # :call-seq:
    #   value -> binary blob
    #   value(range) -> binary blob
    #   value {|chunk| ...}
    #   value(range) {|chunk| ...}
    #
    # Get the value of this port from the server.
    #
    # If no parameters are supplied then this method will simply download and
    # return all the data. Supplying a Range will download and return the data
    # in that range. In these two cases the data is downloaded into memory and
    # cached.
    #
    # Passing in a block will allow access to the underlying data stream. The
    # data is not stored in memory and it is not cached:
    #   run.output_port("port") do |chunk|
    #     print chunk
    #   end
    #
    # No data that has already been cached will be re-downloaded. No data that
    # is streamed will be cached. When downloading port outputs that will not
    # fit into memory, use the streaming versions of this method; do not use
    # the caching versions.
    #
    # If this port is an error then this value will be the error message.
    def value(range = 0...@size, &block)
      # The following block is a workaround for Taverna Server versions prior
      # to 2.4.1 and can be removed when support for those versions is no
      # longer required.
      if error? && @size == 0
        @value = @port.download(@reference)
        @size = @value.size
        @vgot = 0...@size
        return @value
      end

      return "" if @type == EMPTY_TYPE
      return @value if range == :debug

      # Check that the range provided is sensible
      range = 0..range.max if range.min < 0
      range = range.min...@size if range.max >= @size

      need = fill(@vgot, range)
      case need.length
      when 0
        # We already have all the data we need, just return or stream the
        # right bit. @vgot cannot be nil here and must fully encompass range.
        ret_range = (range.min - @vgot.min)..(range.max - @vgot.min)
        if block_given?
          yield @value[ret_range]
        else
          @value[ret_range]
        end
      when 1
        # We either have some data, at one end of range or either side of it,
        # or none. @vgot can be nil here. In both cases we download or stream
        # what we need.
        if @vgot.nil?
          # We have no data, so download or stream it all.
          if block_given?
            @port.download(@reference, need[0], &block)
          else
            @vgot = range
            @value = @port.download(@reference, need[0])
          end
        else
          # Add the new data to the correct end of the data we have, then
          # return or stream the range requested.
          if range.max <= @vgot.max
            if block_given?
              @port.download(@reference, need[0], &block)
              yield @value[0..(range.max - @vgot.min)]
            else
              @vgot = range.min..@vgot.max
              @value = @port.download(@reference, need[0]) + @value
              @value[0..range.max]
            end
          else
            if block_given?
              yield @value[(range.min - @vgot.min)..-1]
              @port.download(@reference, need[0], &block)
            else
              @vgot = @vgot.min..range.max
              @value = @value + @port.download(@reference, need[0])
              @value[(range.min - @vgot.min)..@vgot.max]
            end
          end
        end
      when 2
        # We definitely have some data and it is in the middle of the
        # range requested. @vgot cannot be nil here.
        if block_given?
          @port.download(@reference, need[0], &block)
          yield @value
          @port.download(@reference, need[1], &block)
        else
          @vgot = range
          @value = @port.download(@reference, need[0]) + @value +
            @port.download(@reference, need[1])
        end
      end
    end

    # :call-seq:
    #   stream_value(stream) -> Fixnum
    #   stream_value(stream, range) -> Fixnum
    #
    # Stream this port value directly into another stream. The stream passed
    # in may be anything that provides a +write+ method; instances of IO and
    # File, for example. No data is cached by this method.
    #
    # The number of bytes written to the stream is returned.
    def stream_value(stream, range = 0...@size)
      raise ArgumentError,
        "Stream passed in must provide a write method" unless
          stream.respond_to? :write

      bytes = 0

      value(range) do |chunk|
        bytes += stream.write(chunk)
      end

      bytes
    end

    # :call-seq:
    #   write_value_to_file(filename) -> Fixnum
    #   write_value_to_file(filename, range) -> Fixnum
    #
    # Stream this port value directly to a file. If a range is supplied then
    # just that range of data is downloaded from the server. No data is cached
    # by this method.
    def write_value_to_file(filename, range = 0...@size)
      File.open(filename, "wb") do |file|
        stream_value(file, range)
      end
    end

    # :call-seq:
    #   error? -> bool
    #
    # Does this port represent an error?
    def error?
      @error
    end

    # :call-seq:
    #   empty? -> bool
    #
    # Is this port value empty?
    def empty?
      @type == EMPTY_TYPE
    end

    # :stopdoc:
    def error
      warn "[DEPRECATION] Using #error to get the error message is " +
        "deprecated and will be removed in version 2.0.0. Please use #value " +
        "instead."
      value
    end
    # :startdoc:

    # Used within #inspect, below to help override the built in version.
    @@to_s = Kernel.instance_method(:to_s)

    # :call-seq:
    #   inspect -> string
    #
    # Return a printable representation of this port value for debugging
    # purposes.
    def inspect
      @@to_s.bind(self).call.sub!(/>\z/) { " @value=#{value.inspect}, " +
        "@type=#{type.inspect}, @size=#{size.inspect}>"
      }
    end

    private
    def fill(got, want)
      return [want] if got.nil?

      w_min = want.min
      w_max = want.max
      g_min = got.min
      g_max = got.max

      if got.member? w_min
        if got.member? w_max
          []
        else
          [(g_max + 1)..w_max]
        end
      else
        if got.member? w_max
          [w_min..(g_min - 1)]
        else
          if w_max < g_min
            [w_min..(g_min - 1)]
          elsif w_min > g_max
            [(g_max + 1)..w_max]
          else
            [w_min..(g_min - 1), (g_max + 1)..w_max]
          end
        end
      end
    end
  end
end
