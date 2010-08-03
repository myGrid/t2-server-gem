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

require 'rexml/document'
include REXML

module T2Server
  
  class Run
    
    STATE = {
      :initialized => "Initialized",
      :running     => "Operating",
      :finished    => "Finished",
      :stopped     => "Stopped"
    }
    
    private_class_method :new
    attr_reader :uuid
    
    def initialize(server, uuid)
      @server = server
      @uuid = uuid
      @workflow = ""
      @baclava = false
      
      @links = get_attributes(@server.get_run_attribute(uuid, ""))
      #@links.each {|key, val| puts "#{key}: #{val}"}
    end

    def Run.create(server, workflow, uuid="")
      if server.class == String
        server = Server.connect(server)
      end
      if uuid == ""
        new(server, server.initialize_run(workflow))
      else
        new(server, uuid)
      end
    end
    
    def delete
      @server.delete_run uuid
    end
    
    def inputs
      @links[:inputs]
    end
    
    def set_input(input, value)
      @server.set_run_input(self, input, value)
    end
    
    def set_input_file(input, filename)
      @server.set_run_input_file(self, input, filename)
    end
    
    def get_output(output, type="text/plain")
      return unless finished?   ### raise exception?
      doc = @server.get_run_attribute(@uuid, "#{@links[:wdir]}/out/#{output}")
      doc
    end
    
    def expiry
      @server.get_run_attribute(@uuid, @links[:expiry])
    end
    
    def expiry=(date)
      @server.set_run_attribute(@uuid, @links[:expiry], date)
    end

    def workflow
      if @workflow == ""
        @workflow = @server.get_run_attribute(@uuid, @links[:workflow])
      end
      @workflow
    end
    
    def status
      @server.get_run_attribute(@uuid, @links[:status])
    end
    
    def start
      @server.set_run_attribute(@uuid, @links[:status], STATE[:running])
    end
    
    def wait(params={})
      return unless running?
      
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
    
    def exitcode
      @server.get_run_attribute(@uuid, @links[:exitcode]).to_i
    end
    
    def stdout
      @server.get_run_attribute(@uuid, @links[:stdout])
    end
    
    def stderr
      @server.get_run_attribute(@uuid, @links[:stderr])
    end
    
    def mkdir(dir)
      if dir.include? ?/
        # if a path is given then separate the leaf from the
        # end and add the rest of the path to the wdir link
        leaf = dir.split("/")[-1]
        path = dir[0...-(leaf.length + 1)]
        @server.make_run_dir(@uuid, "#{@links[:wdir]}/#{path}", leaf)
      else
        @server.make_run_dir(@uuid, @links[:wdir], dir)
      end
    end
    
    def upload_file(filename, params={})
      location = params[:dir] || ""
      location = "#{@links[:wdir]}/#{location}"
      rename = params[:rename] || ""
      @server.upload_run_file(@uuid, filename, location, rename)
    end
    
    def upload_input_file(input, filename, params={})
      file = upload_file(filename, params)
      set_input_file(input, file)
    end
    
    def upload_baclava_file(filename)
      @baclava = true
      rename = upload_file(filename)
      @server.set_run_attribute(@uuid, @links[:baclava], rename)
    end

    def ls(dir="")
      dir_list = @server.get_run_attribute(@uuid, "#{@links[:wdir]}/#{dir}")
      doc = Document.new(dir_list)

      # compile a list of directory entries stripping the
      # directory name from the front of each filename
      dirs = []
      files = []
      XPath.each(doc, "//nss:dir", Namespaces::MAP) {|e| dirs << e.text.split('/')[-1]}
      XPath.each(doc, "//nss:file", Namespaces::MAP) {|e| files << e.text.split('/')[-1]}
      [dirs, files]
    end

    def initialized?
      status == STATE[:initialized]
    end
    
    def running?
      status == STATE[:running]
    end
    
    def finished?
      status == STATE[:finished]
    end
    
    def create_time
      @server.get_run_attribute(@uuid, @links[:createtime])
    end
    
    def start_time
      @server.get_run_attribute(@uuid, @links[:starttime])
    end

    def finish_time
      @server.get_run_attribute(@uuid, @links[:finishtime])
    end

    private
    def get_attributes(desc)
      # first parse out the basic stuff
      links = parse_description(desc)
      
      # get inputs
      inputs = @server.get_run_attribute(@uuid, links[:inputs])
      doc = Document.new(inputs)
      nsmap = Namespaces::MAP
      links[:baclava] = "#{links[:inputs]}/" + XPath.first(doc, "//nsr:baclava", nsmap).attributes["href"].split('/')[-1]

      # set io properties
      links[:io]       = "#{links[:listeners]}/io"
      links[:stdout]   = "#{links[:io]}/properties/stdout"
      links[:stderr]   = "#{links[:io]}/properties/stderr"
      links[:exitcode] = "#{links[:io]}/properties/exitcode"
      
      links
    end

    def parse_description(desc)
      doc = Document.new(desc)
      nsmap = Namespaces::MAP
      {
        :expiry     => XPath.first(doc, "//nsr:expiry", nsmap).attributes["href"].split('/')[-1],
        :workflow   => XPath.first(doc, "//nsr:creationWorkflow", nsmap).attributes["href"].split('/')[-1],
        :status     => XPath.first(doc, "//nsr:status", nsmap).attributes["href"].split('/')[-1],
        :createtime => XPath.first(doc, "//nsr:createTime", nsmap).attributes["href"].split('/')[-1],
        :starttime  => XPath.first(doc, "//nsr:startTime", nsmap).attributes["href"].split('/')[-1],
        :finishtime => XPath.first(doc, "//nsr:finishTime", nsmap).attributes["href"].split('/')[-1],
        :wdir       => XPath.first(doc, "//nsr:workingDirectory", nsmap).attributes["href"].split('/')[-1],
        :inputs     => XPath.first(doc, "//nsr:inputs", nsmap).attributes["href"].split('/')[-1],
        :output     => XPath.first(doc, "//nsr:output", nsmap).attributes["href"].split('/')[-1],
        :securectx  => XPath.first(doc, "//nsr:securityContext", nsmap).attributes["href"].split('/')[-1],
        :listeners  => XPath.first(doc, "//nsr:listeners", nsmap).attributes["href"].split('/')[-1]
      }
    end
  end
end
