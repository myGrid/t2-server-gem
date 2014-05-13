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

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "t2-server/version"

Gem::Specification.new do |s|
  s.name             = "t2-server"
  s.version          = T2Server::Version::STRING
  s.authors          = ["Robert Haines", "Finn Bacall"]
  s.email            = ["support@mygrid.org.uk"]
  s.homepage         = "http://www.taverna.org.uk/"
  s.platform         = Gem::Platform::RUBY
  s.summary          = "Support for interacting with Taverna 2 Server."
  s.description      = "This gem provides access to the Taverna 2 Server " +
                         "REST interface from Ruby."
  s.license          = "BSD"
  s.require_path     = "lib"
  s.bindir           = "bin"
  s.files            = `git ls-files`.split($/)
  s.executables      = ["t2-delete-runs", "t2-run-workflow", "t2-server-info",
                          "t2-get-output", "t2-server-admin"]
  s.test_file        = "test/ts_t2server.rb"
  s.has_rdoc         = true
  s.extra_rdoc_files = ["README.rdoc", "LICENCE.rdoc", "CHANGES.rdoc"]
  s.rdoc_options     = ["-N", "--tab-width=2", "--main=README.rdoc"]
  s.required_ruby_version = ">= 1.9.3"
  s.add_development_dependency('rake', '~> 10.0')
  s.add_development_dependency('bundler', '~> 1.5')
  s.add_development_dependency('rdoc', '~> 4.1')
  s.add_development_dependency('launchy', '~> 2.2')
  s.add_development_dependency('hirb', '~> 0.7')
  s.add_runtime_dependency('net-http-persistent', '~> 2.6')
  s.add_runtime_dependency('taverna-baclava', '~> 1.0')
  s.add_runtime_dependency('ratom', '~> 0.8.2')
  s.add_runtime_dependency('libxml-ruby', '~> 2.6')
end
