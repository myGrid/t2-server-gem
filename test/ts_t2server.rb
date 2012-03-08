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

require 'test/unit'
require 't2-server'

# Check for a server address and user credentials passed through on the
# command line.
if ARGV.size != 0
  address = ARGV[0]

  unless ARGV[1].nil?
    user1, pass1 = ARGV[1].split(":")
    user1 = nil if pass1.nil?
  end

  unless ARGV[2].nil?
    user2, pass2 = ARGV[2].split(":")
    user2 = nil if pass2.nil?
  end

  puts "Using server at: #{address}"
  puts "   With user(s): #{user1} #{user2}" if user1
else
  # get a server address to test - 30 second timeout
  print "\nPlease supply a valid Taverna 2 Server address.\n\nNOTE that " +
    "these tests will fully load the server and then delete all the runs " +
    "that it has permission to do so - if you are not using security ALL " +
    "runs will be deleted!\n(leave blank to skip tests): "
  $stdout.flush
  if select([$stdin], [], [], 30)
    address = $stdin.gets.chomp
  else
    puts "\nSkipping tests that require a Taverna 2 Server instance..."
    address = ""
  end
end

# the testcases to run
require 'tc_util'
require 'tc_params'
if address != ""
  $uri, $creds = T2Server::Util.strip_uri_credentials(address)

  # override creds if passed in on the command line
  $creds = T2Server::HttpBasic.new(user1, pass1) if user1
  $creds1 = T2Server::HttpBasic.new(user2, pass2) if user2

  $wkf_pass   = File.read("test/workflows/pass_through.t2flow")
  $wkf_lists  = File.read("test/workflows/empty_list.t2flow")
  $wkf_xml    = File.read("test/workflows/xml_xpath.t2flow")
  $wkf_fail   = File.read("test/workflows/always_fail.t2flow")
  $wkf_errors = File.read("test/workflows/list_with_errors.t2flow")
  $list_input = "test/workflows/empty_list_input.baclava"
  $file_input = "test/workflows/in.txt"
  $file_strs  = "test/workflows/strings.txt"

  if $uri.scheme == "http"
    $conn_params = T2Server::DefaultConnectionParameters.new
  else
    $conn_params = T2Server::InsecureSSLConnectionParameters.new
  end

  require 'tc_server'

  # get the server version to determine which test cases to run
  if T2Server::Server.new($uri, $conn_params).version == 1
    require 'tc_run_v1'
  else
    require 'tc_run'
    require 'tc_admin'
    require 'tc_secure'

    # if we have two sets of credentials we can run permissions tests
    if $creds1
      require 'tc_perms'
    end
  end
end
