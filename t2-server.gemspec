# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "t2-server"
  s.version = "0.9.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Robert Haines"]
  s.date = "2012-04-30"
  s.description = "This gem provides access to the Taverna 2 Server REST interface from Ruby."
  s.email = ["rhaines@manchester.ac.uk"]
  s.executables = ["t2-delete-runs", "t2-run-workflow", "t2-server-info", "t2-get-output", "t2-server-admin"]
  s.extra_rdoc_files = [
    "CHANGES.rdoc",
    "LICENCE.rdoc",
    "README.rdoc"
  ]
  s.files = [
    "CHANGES.rdoc",
    "LICENCE.rdoc",
    "README.rdoc",
    "Rakefile",
    "bin/t2-delete-runs",
    "bin/t2-get-output",
    "bin/t2-run-workflow",
    "bin/t2-server-admin",
    "bin/t2-server-info",
    "lib/t2-server-cli.rb",
    "lib/t2-server.rb",
    "lib/t2-server/admin.rb",
    "lib/t2-server/exceptions.rb",
    "lib/t2-server/net/connection.rb",
    "lib/t2-server/net/credentials.rb",
    "lib/t2-server/net/parameters.rb",
    "lib/t2-server/port.rb",
    "lib/t2-server/run.rb",
    "lib/t2-server/server.rb",
    "lib/t2-server/util.rb",
    "lib/t2-server/xml/libxml.rb",
    "lib/t2-server/xml/nokogiri.rb",
    "lib/t2-server/xml/rexml.rb",
    "lib/t2-server/xml/xml.rb",
    "lib/t2server.rb",
    "t2-server.gemspec",
    "test/tc_admin.rb",
    "test/tc_params.rb",
    "test/tc_perms.rb",
    "test/tc_run.rb",
    "test/tc_secure.rb",
    "test/tc_server.rb",
    "test/tc_util.rb",
    "test/ts_t2server.rb",
    "test/workflows/always_fail.t2flow",
    "test/workflows/empty_list.t2flow",
    "test/workflows/empty_list_input.baclava",
    "test/workflows/in.txt",
    "test/workflows/list_and_value.t2flow",
    "test/workflows/list_with_errors.t2flow",
    "test/workflows/pass_through.t2flow",
    "test/workflows/secure/basic-http.t2flow",
    "test/workflows/secure/basic-https.t2flow",
    "test/workflows/secure/client-https.t2flow",
    "test/workflows/secure/digest-http.t2flow",
    "test/workflows/secure/digest-https.t2flow",
    "test/workflows/secure/heater-pk.pem",
    "test/workflows/secure/user-cert.p12",
    "test/workflows/secure/ws-http.t2flow",
    "test/workflows/secure/ws-https.t2flow",
    "test/workflows/strings.txt",
    "test/workflows/xml_xpath.t2flow",
    "version.yml"
  ]
  s.homepage = "http://www.taverna.org.uk/"
  s.rdoc_options = ["-N", "--tab-width=2", "--main=README.rdoc"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.21"
  s.summary = "Support for interacting with Taverna 2 Server."
  s.test_files = ["test/ts_t2server.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rake>, ["~> 0.9.2"])
      s.add_development_dependency(%q<libxml-ruby>, [">= 1.1.4"])
      s.add_development_dependency(%q<nokogiri>, [">= 1.5.0"])
      s.add_development_dependency(%q<rdoc>, [">= 3.9.4"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.8.3"])
      s.add_runtime_dependency(%q<net-http-persistent>, ["~> 2.6"])
      s.add_runtime_dependency(%q<taverna-baclava>, ["~> 1.0.0"])
      s.add_runtime_dependency(%q<hirb>, [">= 0.4.0"])
    else
      s.add_dependency(%q<rake>, ["~> 0.9.2"])
      s.add_dependency(%q<libxml-ruby>, [">= 1.1.4"])
      s.add_dependency(%q<nokogiri>, [">= 1.5.0"])
      s.add_dependency(%q<rdoc>, [">= 3.9.4"])
      s.add_dependency(%q<jeweler>, ["~> 1.8.3"])
      s.add_dependency(%q<net-http-persistent>, ["~> 2.6"])
      s.add_dependency(%q<taverna-baclava>, ["~> 1.0.0"])
      s.add_dependency(%q<hirb>, [">= 0.4.0"])
    end
  else
    s.add_dependency(%q<rake>, ["~> 0.9.2"])
    s.add_dependency(%q<libxml-ruby>, [">= 1.1.4"])
    s.add_dependency(%q<nokogiri>, [">= 1.5.0"])
    s.add_dependency(%q<rdoc>, [">= 3.9.4"])
    s.add_dependency(%q<jeweler>, ["~> 1.8.3"])
    s.add_dependency(%q<net-http-persistent>, ["~> 2.6"])
    s.add_dependency(%q<taverna-baclava>, ["~> 1.0.0"])
    s.add_dependency(%q<hirb>, [">= 0.4.0"])
  end
end

