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

module T2Server
  # :stopdoc:
  module Namespaces
    SERVER = "http://ns.taverna.org.uk/2010/xml/server/"
    REST   = SERVER + "rest/"
    MAP    = {
      "nss" => Namespaces::SERVER,
      "nsr" => Namespaces::REST
    }
  end

  module Fragments
    WORKFLOW      = "<t2s:workflow xmlns:t2s=\"#{Namespaces::SERVER}\">\n  %s\n</t2s:workflow>"
    RUNINPUT      = "<t2sr:runInput xmlns:t2sr=\"#{Namespaces::REST}\">\n  %s\n</t2sr:runInput>"
    RUNINPUTVALUE = RUNINPUT % "<t2sr:value>%s</t2sr:value>"
    RUNINPUTFILE  = RUNINPUT % "<t2sr:file>%s</t2sr:file>"
    UPLOAD        = "<t2sr:upload xmlns:t2sr=\"#{Namespaces::REST}\" t2sr:name=\"%s\">\n  %s\n</t2sr:upload>"
    MKDIR         = "<t2sr:mkdir xmlns:t2sr=\"#{Namespaces::REST}\" t2sr:name=\"%s\" />"
  end

  module XPaths
    include LibXML

    # Shut the libxml error handler up
    XML::Error.set_handler(&XML::Error::QUIET_HANDLER)

    # Server XPath queries
    RUN      = XML::XPath::Expression.new("//nsr:run")
    RUNS     = XML::XPath::Expression.new("//nsr:runs")
    RUNLIMIT = XML::XPath::Expression.new("//nsr:runLimit")
    PERMWKF  = XML::XPath::Expression.new("//nsr:permittedWorkflows")
    PERMLSTN = XML::XPath::Expression.new("//nsr:permittedListeners")

    # Run XPath queries
    DIR        = XML::XPath::Expression.new("//nss:dir")
    FILE       = XML::XPath::Expression.new("//nss:file")
    EXPIRY     = XML::XPath::Expression.new("//nsr:expiry")
    WORKFLOW   = XML::XPath::Expression.new("//nsr:creationWorkflow")
    STATUS     = XML::XPath::Expression.new("//nsr:status")
    CREATETIME = XML::XPath::Expression.new("//nsr:createTime")
    STARTTIME  = XML::XPath::Expression.new("//nsr:startTime")
    FINISHTIME = XML::XPath::Expression.new("//nsr:finishTime")
    WDIR       = XML::XPath::Expression.new("//nsr:workingDirectory")
    INPUTS     = XML::XPath::Expression.new("//nsr:inputs")
    OUTPUT     = XML::XPath::Expression.new("//nsr:output")
    SECURECTX  = XML::XPath::Expression.new("//nsr:securityContext")
    LISTENERS  = XML::XPath::Expression.new("//nsr:listeners")
    BACLAVA    = XML::XPath::Expression.new("//nsr:baclava")
  end
  # :startdoc:
end
