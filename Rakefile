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

require 'rubygems'
require 'rake'
require 'rake/clean'
require 'rake/tasklib'
require 'rdoc/task'
require 'jeweler'

# we need to add lib to the path because we're not installed yet!
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), "lib")
require 't2-server'

task :default => [:test]

Jeweler::Tasks.new do |s|
  s.name             = "t2-server"
  s.version          = T2Server::Version::STRING
  s.authors          = ["Robert Haines"]
  s.email            = ["rhaines@manchester.ac.uk"]
  s.homepage         = "http://www.taverna.org.uk/"
  s.platform         = Gem::Platform::RUBY
  s.summary          = "Support for interacting with Taverna 2 Server."
  s.description      = "This gem provides access to the Taverna 2 Server " +
                         "REST interface from Ruby."
  s.require_path     = "lib"
  s.bindir           = "bin"
  s.executables      = ["t2-delete-runs", "t2-run-workflow", "t2-server-info",
                          "t2-get-output", "t2-server-admin"]
  s.test_file        = "test/ts_t2server.rb"
  s.has_rdoc         = true
  s.extra_rdoc_files = ["README.rdoc", "LICENCE.rdoc", "CHANGES.rdoc"]
  s.rdoc_options     = ["-N", "--tab-width=2", "--main=README.rdoc"]
  s.add_development_dependency('rake', '~> 0.9.2')
  s.add_development_dependency('libxml-ruby', '>= 1.1.4')
  s.add_development_dependency('nokogiri', '>= 1.5.0')
  s.add_development_dependency('rdoc', '>= 3.9.4')
  s.add_development_dependency('jeweler', '~> 1.8.3')
  s.add_runtime_dependency('net-http-persistent', '~> 2.6')
  s.add_runtime_dependency('taverna-baclava', '~> 1.0.0')
  s.add_runtime_dependency('ratom', '~> 0.7.2')
  s.add_runtime_dependency('hirb', '>= 0.4.0')
  s.add_runtime_dependency('launchy', '~> 2.1.2')
end

# This test task does not use the standard Rake::TestTask class as we need to
# be able to supply an argument to the test. This is so that the test can be
# run with a server address from a CI server. The equivalent TestTask would be
# something like this:
#
#  Rake::TestTask.new do |t|
#    t.libs << "test"
#    t.test_files = FileList['test/ts_t2server.rb']
#    t.verbose = true
#  end
task :test, [:server, :user1, :user2] do |t, args|
  args.with_defaults(:server => "", :user1 => "", :user2 => "")
  RakeFileUtils.verbose(true) do
    server_arg = ""
    if args[:server] != ""
      server_arg = "#{args[:server]} #{args[:user1]} #{args[:user2]}"
    end
    ruby "-I\"lib:test\" test/ts_t2server.rb " + server_arg
  end
end

RDoc::Task.new do |r|
  r.main = "README.rdoc"
  lib = Dir.glob("lib/**/*.rb").delete_if do |item|
    item.include?("/xml/") or
    item.include?("connection.rb") or
    item.include?("t2-server-cli.rb")
  end
  r.rdoc_files.include("README.rdoc", "LICENCE.rdoc", "CHANGES.rdoc", lib)
  r.options << "-t Taverna 2 Server Ruby Interface Library version " +
    "#{T2Server::Version::STRING}"
  r.options << "-N"
  r.options << "--tab-width=2"
end