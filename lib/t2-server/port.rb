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

module T2Server

  # Base class of InputPort and OutputPort
  class Port
    # The port's name
    attr_reader :name

    # The "depth" of the port. 0 = a singleton value.
    attr_reader :depth

    # :stopdoc:
    # Create a new port.
    def initialize(run, xml)
      @run = run
      @xml = xml

      parse_xml(xml)
    end
    # :startdoc:

    private
    def parse_xml(xml)
      @name = xml.attributes["name"]
      @depth = xml.attributes["depth"].to_i
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
      @baclava = nil
    end
    # :startdoc:

    # :call-seq:
    #   value = value
    #
    # Set the value of this input port. This also sets the port's value on the
    # server.
    def value=(value)
      if @run.set_input(@name, value)
        @file = nil
        @baclava = false
        @value = value
      end
    end

    # :call-seq:
    #   file? -> bool
    #
    # Is this port's data being supplied by a file?
    def file?
      !@file.nil?
    end

    # :call-seq:
    #   file = filename
    #
    # Set the file to use for this port's data. This also uploads the data to
    # the server.
    def file=(filename)
      file = @run.upload_input_file(@name, filename)
      unless file.nil?
        @value = nil
        @baclava = false
        @file = file
      end
    end

    # :call-seq:
    #   baclava? -> bool
    #
    # Has this port been set via a baclava document?
    def baclava?
      @baclava
    end

    # :stopdoc:
    # Set whether this port has been set via a baclava document.
    def baclava=(toggle)
      @value = nil
      @file = nil
      @baclava = toggle
    end
    # :startdoc:

    # :call-seq:
    #   set? -> bool
    #
    # Has this port been set?
    def set?
      !value.nil? or file? or baclava?
    end
  end
end
