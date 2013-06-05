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

  # This call provides access to the administrative interface of a Taverna
  # Server instance.
  #
  # To get an instance of this class use the Server#administrator method.
  # Special permissions will most likely be required above and beyond those
  # assigned to most Taverna Server users.
  class Administrator
    include XML::Methods

    # The resources held by this administrative interface. This is a Hash
    # indexed by the name of the resource in lowercase.
    attr_reader :resources

    # :stopdoc:
    ADMIN_ENDPOINT = "admin"

    def initialize(server, credentials = nil)
      @server = server
      @uri = Util.append_to_uri_path(server.uri, ADMIN_ENDPOINT)
      @credentials = credentials

      admin_description = xml_document(@server.read(@uri, "application/xml",
        @credentials))
      @resources = get_resources(admin_description)

      yield(self) if block_given?
    end
    # :startdoc:

    # :call-seq:
    #   [name] -> AdminResource
    #
    # Return the named AdminResource.
    def [](name)
      @resources[name.downcase]
    end

    # :stopdoc:
    def get_resource_value(uri)
      @server.read(uri, "text/plain", @credentials)
    end

    def set_resource_value(uri, val)
      @server.update(uri, val.to_s, "text/plain", @credentials)
    end
    # :startdoc:

    private
    def get_resources(doc)
      links = {}

      xml_children(doc.root) do |res|
        uri = URI.parse(xml_node_attribute(res, 'href'))
        write = @server.is_resource_writable?(uri, @credentials)
        links[res.name.downcase] = AdminResource.new(res.name, uri, write, self)
      end

      links
    end

    # This class represents a resource in the Taverna Server administrative
    # interface. A resource can be read only or read/write.
    #
    # Resources are created when the parent Administrator class is created and
    # are accessed via the [] method within that class.
    class AdminResource
      # The name of this resource.
      attr_reader :name

      # The URI of this resource on the server.
      attr_reader :uri

      # :stopdoc:
      def initialize(name, uri, writeable, parent)
        @name = name
        @uri = uri
        @admin = parent
        @writeable = writeable

        make_writable if @writeable
      end
      # :startdoc:

      # :call-seq:
      #   value -> String
      #   value=
      #
      # Get or set the value held by this resource. This call always queries
      # the server as values can change without user intervention.
      #
      # The resource can only be set if it is writable.
      def value
        @admin.get_resource_value(@uri)
      end

      # :call-seq:
      #   writable? -> true or false
      #
      # Is this resource writable?
      def writable?
        @writeable
      end

      private
      def make_writable
        (class << self; self; end).instance_eval do
          define_method "value=" do |value|
            @admin.set_resource_value(@uri, value)
          end
        end
      end
    end
  end
end
