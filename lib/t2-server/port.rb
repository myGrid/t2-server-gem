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
      !value.nil? or file? or baclava?
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
    #   value -> obj
    #   value(range) -> obj
    #   value -> Array
    #
    # For singleton outputs get the value (or part of it). For list outputs
    # get all the values in an Array structure that mirrors the structure of
    # the output port. To get part of a value from a list use
    # 'port[].value(range)'.
    def value(range = nil)
      if depth == 0
        if range.nil?
          @structure.value
        else
          @structure.value(range)
        end
      else
        @values = strip(:value) if @values.nil?
        @values
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
      @refs = strip(:reference) if @refs.nil?
      @refs
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
      @types = strip(:type) if @types.nil?
      @types
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
      @sizes = strip(:size) if @sizes.nil?
      @sizes
    end

    # :stopdoc:
    def error
      warn "[DEPRECATION] Using #error to get the error message is " +
      "deprecated and will be removed in version 1.1.0. Please use #value " +
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

    # :stopdoc:
    def download(uri, range = nil)
      @run.download_output_data(uri, range)
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
    #   value -> obj
    #   value(range) -> obj
    #
    # Return the value of this port. It is downloaded from the server if it
    # has not already been retrieved. If a range is specified then just that
    # portion of the value is downloaded and returned. If no range is specified
    # then the whole value is downloaded and returned.
    #
    # If this port is an error then this value will be the error message.
    #
    # All downloaded data is cached and not downloaded a second time if the
    # same or similar ranges are requested.
    def value(range = 0...@size)
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

      # check that the range provided is sensible
      range = 0..range.max if range.min < 0
      range = range.min...@size if range.max >= @size

      need = fill(@vgot, range)
      case need.length
      when 0
        # we already have all the data we need, just return the right bit.
        # @vgot cannot be nil here and must fully encompass range.
        ret_range = (range.min - @vgot.min)..(range.max - @vgot.min)
        @value[ret_range]
      when 1
        # we either have some data, at one end of range or either side of it,
        # or none. @vgot can be nil here.
        # In both cases we download what we need.
        new_data = @port.download(@reference, need[0])
        if @vgot.nil?
          # this is the only data we have, return it all.
          @vgot = range
          @value = new_data
        else
          # add the new data to the correct end of the data we have, then
          # return the range requested.
          if range.max <= @vgot.max
            @vgot = range.min..@vgot.max
            @value = new_data + @value
            @value[0..range.max]
          else
            @vgot = @vgot.min..range.max
            @value = @value + new_data
            @value[(range.min - @vgot.min)..@vgot.max]
          end
        end
      when 2
        # we definitely have some data and it is in the middle of the
        # range requested. @vgot cannot be nil here.
        @vgot = range
        @value = @port.download(@reference, need[0]) + @value +
          @port.download(@reference, need[1])
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
        "deprecated and will be removed in version 1.1.0. Please use #value " +
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

      if got.member? want.min
        if got.member? want.max
          return []
        else
          return [(got.max + 1)..want.max]
        end
      else
        if got.member? want.max
          return [want.min..(got.min - 1)]
        else
          if want.max < got.min
            return [want.min..(got.min - 1)]
          elsif want.min > got.max
            return [(got.max + 1)..want.max]
          else
            return [want.min..(got.min - 1), (got.max + 1)..want.max]
          end
        end
      end
    end
  end
end
