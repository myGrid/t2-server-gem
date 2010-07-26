# Copyright (c) 2010, The University of Manchester, UK.
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
require 'net/http'
require 'rexml/document'
include REXML

module T2Server
  class Server
    private_class_method :new
    attr_reader :uri, :run_limit
    
    # list of servers we know about
    @@servers = []
    
    def initialize(uri)
      @uri = uri
      uri = URI.parse(uri)
      @host = uri.host
      @port = uri.port
      @base_path = uri.path
      @rest_path = uri.path + "/rest"
      @links = parse_description(get_attribute(@rest_path))
      #@links.each {|key, val| puts "#{key}: #{val}"}
      
      # get max runs
      @run_limit = get_attribute(@links[:runlimit]).to_i
      
      # initialise run list
      @runs = {}
      @runs = get_runs
    end

    def Server.connect(uri)
      # see if we've already got this server
      server = @@servers.find {|s| s.uri == uri}

      if !server
        # no, so create new one and return it
        server = new(uri)
        @@servers << server
      end
      
      server
    end
    
    def create_run(workflow)
      uuid = initialize_run(workflow)
      @runs[uuid] = Run.create(self, "", uuid)
    end
    
    def initialize_run(workflow)
      request = Net::HTTP::Post.new("#{@links[:runs]}")
      request.content_type = "application/xml"
      response = Net::HTTP.new(@host, @port).start do |http|
        http.request(request, Fragments::WORKFLOW % workflow)
      end
      
      case response
      when Net::HTTPCreated
        # return the uuid of the newly created run
        epr = URI.parse(response['location'])
        epr.path[-36..-1]
      when Net::HTTPForbidden
        puts "Sorry, but the server is already running its configured limit of concurrent workflows."
        puts "Please try again later."
        ""
      else
        response_error(response)
        ""
      end
    end
    
    def runs
      get_runs.values
    end
    
    def run(uuid)
      get_runs[uuid]
    end

    def delete_run(uuid)
      request = Net::HTTP::Delete.new("#{@links[:runs]}/#{uuid}")
      response = Net::HTTP.new(@host, @port).start {|http| http.request(request)}
      
      case response
      when Net::HTTPNoContent
        # Success, carry on...
        @runs.delete(uuid)
        true
      when Net::HTTPNotFound
        puts "Cannot find run #{run.uuid}."
        false
      else
        response_error(response)
      end
    end
    
    def delete_all_runs
      # first refresh run list
      runs.each {|run| run.delete}
    end
    
    def set_run_input(run, input, value)
      request = Net::HTTP::Put.new("#{@links[:runs]}/#{run.uuid}/#{run.inputs}/input/#{input}")
      request.content_type = "application/xml"
      response = Net::HTTP.new(@host, @port).start do |http|
        http.request(request, Fragments::RUNINPUTVALUE % value)
      end
      
      case response
      when Net::HTTPOK
        # Yay!
        true
      else
        response_error(response)
      end
    end

    def set_run_input_file(run, input, filename)
      request = Net::HTTP::Put.new("#{@links[:runs]}/#{run.uuid}/#{run.inputs}/input/#{input}")
      request.content_type = "application/xml"
      response = Net::HTTP.new(@host, @port).start do |http|
        http.request(request, Fragments::RUNINPUTFILE % filename)
      end
      
      case response
      when Net::HTTPOK
        # Yay!
        true
      else
        response_error(response)
      end
    end

    def make_run_dir(uuid, root, dir)
      request = Net::HTTP::Post.new("#{@links[:runs]}/#{uuid}/#{root}")
      request.content_type = "application/xml"
      response = Net::HTTP.new(@host, @port).start do |http|
        http.request(request,  Fragments::MKDIR % dir)
      end
      
      case response
      when Net::HTTPCreated
        # OK, carry on...
        true
      when Net::HTTPForbidden
        puts "Error!", response.body
        false
      when Net::HTTPNotFound
        puts "Cannot find run #{uuid}."
        false
      else
        response_error(response)
      end
    end
    
    def upload_run_file(uuid, filename, location, rename)
      contents = Base64.encode64(IO.read(filename))
      rename = filename.split('/')[-1] if rename == ""
      request = Net::HTTP::Post.new("#{@links[:runs]}/#{uuid}/#{location}")
      request.content_type = "application/xml"
      response = Net::HTTP.new(@host, @port).start do |http|
        http.request(request,  Fragments::UPLOAD % [rename, contents])
      end
      
      case response
      when Net::HTTPCreated
        # Success, return remote name of uploaded file
        rename
      when Net::HTTPForbidden
        puts "Error!", response.body
      else
        response_error(response)
      end
    end

    def get_run_attribute(uuid, path)
      get_attribute("#{@links[:runs]}/#{uuid}/#{path}")
    end

    def set_run_attribute(uuid, path, value)
      request = Net::HTTP::Put.new("#{@links[:runs]}/#{uuid}/#{path}")
      request.content_type = "text/plain"
      response = Net::HTTP.new(@host, @port).start {|http| http.request(request, value)}
      
      case response
      when Net::HTTPOK
        # OK, so carry on
        true
      when Net::HTTPForbidden
        puts "Error!"
        puts response.body
        false
      when Net::HTTPNotFound
        puts "Cannot find run #{uuid}."
        false
      else
        response_error(response)
      end
    end
    
    private
    def get_attribute(path)
      request = Net::HTTP::Get.new(path)
      response = Net::HTTP.new(@host, @port).start {|http| http.request(request)}
      
      case response
      when Net::HTTPOK
        return response.body
      when Net::HTTPNotFound
        puts "Cannot find attribute #{path}."
      when Net::HTTPForbidden
        puts "Verboten!"
      else
        response_error(response)
      end
    end

    def parse_description(desc)
      doc = Document.new(desc)
      nsmap = Namespaces::MAP
      {
        :runs          => URI.parse(XPath.first(doc, "//nsr:runs", nsmap).attributes["href"]).path,
        :runlimit      => URI.parse(XPath.first(doc, "//nsr:runLimit", nsmap).attributes["href"]).path,
        :permworkflows => URI.parse(XPath.first(doc, "//nsr:permittedWorkflows", nsmap).attributes["href"]).path,
        :permlisteners => URI.parse(XPath.first(doc, "//nsr:permittedListeners", nsmap).attributes["href"]).path
      }
    end
    
    def response_error(response)
      puts "Unnexpected response from Taverna Server!"
      puts "Server is: #{@host}:#{@port}#{@base_path}"
      puts "Response code is: #{response.code}"
      if response.body
        puts "Response body is: \n#{response.body}"
      end
      puts "\nRaw error is: \n#{response.error!}"
      false
    end
    
    def get_runs
      run_list = get_attribute("#{@links[:runs]}")

      doc = Document.new(run_list)

      # get list of run uuids
      uuids = []
      XPath.each(doc, "//nsr:run", Namespaces::MAP) do |run|
        uuids << run.attributes["href"].split('/')[-1]
      end

      # add new runs
      uuids.each do |uuid|
        if !@runs.has_key? uuid
          @runs[uuid] = Run.create(self, "", uuid)
        end
      end

      # clear out the expired runs
      if @runs.length > @run_limit
        @runs.delete_if {|key, val| !uuids.member? key}
      end

      @runs
    end
  end  
end
