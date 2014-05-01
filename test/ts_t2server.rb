# Copyright (c) 2010-2014 The University of Manchester, UK.
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

  puts "Running tests against a live server at: #{address}"
  puts "   With user(s): #{user1} #{user2}" if user1

  # Clear the commandline arguments so that we don't confuse runit.
  ARGV.clear
end

# If address is still unset then set it to something.
address ||= ""

# the testcases to run
require 'tc_util'
require 'tc_params'
require 'tc_connection_factory'
require 'tc_server_version'

# Only run tests against a live server if we have an address for one.
if address == ""
  $uri = URI.parse("http://localhost/taverna")
  $creds = T2Server::HttpBasic.new("test", "test")
  $userinfo = "test:test"
  $conn_params = T2Server::DefaultConnectionParameters.new

  require 'tc_server'
else
  $uri, $creds = T2Server::Util.strip_uri_credentials(address)

  # override creds if passed in on the command line
  $creds = T2Server::HttpBasic.new(user1, pass1) if user1
  $creds1 = T2Server::HttpBasic.new(user2, pass2) if user2

  $wkf_pass   = "test/workflows/pass_through.t2flow"
  $wkf_lists  = "test/workflows/empty_list.t2flow"
  $wkf_l_v    = "test/workflows/list_and_value.t2flow"
  $wkf_xml    = "test/workflows/xml_xpath.t2flow"
  $wkf_fail   = "test/workflows/always_fail.t2flow"
  $wkf_errors = "test/workflows/list_with_errors.t2flow"
  $wkf_no_io  = "test/workflows/no-ports.t2flow"
  $wkf_miss_o = "test/workflows/missing_outputs.t2flow"
  $list_input = "test/workflows/empty_list_input.baclava"
  $file_input = "test/workflows/in.txt"
  $file_strs  = "test/workflows/strings.txt"

  if $uri.scheme == "http"
    $conn_params = T2Server::DefaultConnectionParameters.new
  else
    $conn_params = T2Server::InsecureSSLConnectionParameters.new
  end

  # We only support version 2.3 server and onwards now...
  begin
    # This will drop out before further tests are run
    T2Server::Server.new($uri, $conn_params)

    require 'tc_server_live'
    require 'tc_run_live'
    require 'tc_admin_live'
    require 'tc_secure_live'
    require 'tc_misc_live'

    # if we have two sets of credentials we can run permissions tests
    if $creds1
      require 'tc_perms_live'
    end
  rescue RuntimeError => e
    puts "!!!\nNo tests on the remote server could be run.\n#{e.message}\n!!!"
  end
end
