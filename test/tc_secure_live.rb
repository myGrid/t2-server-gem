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

require 't2-server'

class TestSecurity < Test::Unit::TestCase

  # Details on secure tests for Taverna are here:
  # http://www.mygrid.org.uk/dev/wiki/display/story/Taverna+2.x+test+secure+services+and+workflows

  # User name and password for the test secure server.
  USERNAME = "testuser"
  PASSWORD = "testpasswd"

  # Various URIs required.
  HEATER_HTTP  = "http://heater.cs.man.ac.uk:7070/"
  HEATER_HTTPS = "https://heater.cs.man.ac.uk:7443/"
  HEATER_CAUTH = "https://heater.cs.man.ac.uk:7444/"
  WS1          = "axis/services/HelloService-PlaintextPassword?wsdl"
  WS2          = "axis/services/HelloService-DigestPassword?wsdl"
  WS3          = "axis/services/HelloService-PlaintextPassword-Timestamp?wsdl"
  WS4          = "axis/services/HelloService-DigestPassword-Timestamp?wsdl"

  # Workflows
  WKF_BASIC_HTTP   = File.read("test/workflows/secure/basic-http.t2flow")
  WKF_DIGEST_HTTP  = File.read("test/workflows/secure/digest-http.t2flow")
  WKF_WS_HTTP      = File.read("test/workflows/secure/ws-http.t2flow")
  WKF_BASIC_HTTPS  = File.read("test/workflows/secure/basic-https.t2flow")
  WKF_DIGEST_HTTPS = File.read("test/workflows/secure/digest-https.t2flow")
  WKF_WS_HTTPS     = File.read("test/workflows/secure/ws-https.t2flow")
  WKF_CLIENT_HTTPS = File.read("test/workflows/secure/client-https.t2flow")

  # Server public key for HTTPS peer verification.
  HEATER_PK = "test/workflows/secure/heater-pk.pem"

  # Client private key for HTTPS authentication
  USER_PK = "test/workflows/secure/user-cert.p12"
  CERTNAME = "{492EB700-ADBA-44B9-A263-D7DF9F2E0F2B}"
  CERTPASS = "testcert"

  # HTTP Basic authentication
  def test_basic_creds_http
    T2Server::Run.create($uri, WKF_BASIC_HTTP, $creds, $conn_params) do |run|
      run.add_password_credential(HEATER_HTTP, USERNAME, PASSWORD)
      run.start
      assert(run.running?)
      assert_nothing_raised(T2Server::RunStateError) { run.wait }
      assert(run.finished?)
      refute(run.output_port("out").error?)
      assert(run.delete)
    end

    # now test with no credential
    T2Server::Run.create($uri, WKF_BASIC_HTTP, $creds, $conn_params) do |run|
      run.start
      assert(run.running?)
      assert_nothing_raised(T2Server::RunStateError) { run.wait }
      assert(run.finished?)
      assert(run.output_port("out").error?)
      assert(run.delete)
    end
  end

  # HTTPS Basic authentication
  def test_basic_creds_https
    T2Server::Run.create($uri, WKF_BASIC_HTTPS, $creds, $conn_params) do |run|
      run.add_password_credential(HEATER_HTTPS, USERNAME, PASSWORD)
      run.add_trust(HEATER_PK)
      run.start
      assert(run.running?)
      assert_nothing_raised(T2Server::RunStateError) { run.wait }
      assert(run.finished?)
      refute(run.output_port("out").error?)
      assert(run.delete)
    end

    # now test with no server public key
    T2Server::Run.create($uri, WKF_BASIC_HTTPS, $creds, $conn_params) do |run|
      run.add_password_credential(HEATER_HTTPS, USERNAME, PASSWORD)
      run.start
      assert(run.running?)
      assert_nothing_raised(T2Server::RunStateError) { run.wait }
      assert(run.finished?)
      assert(run.output_port("out").error?)
      assert(run.delete)
    end
  end

  # HTTP Digest authentication
  def test_digest_creds_http
    T2Server::Run.create($uri, WKF_DIGEST_HTTP, $creds, $conn_params) do |run|
      run.add_password_credential(HEATER_HTTP, USERNAME, PASSWORD)
      run.start
      assert(run.running?)
      assert_nothing_raised(T2Server::RunStateError) { run.wait }
      assert(run.finished?)
      refute(run.output_port("out").error?)
      assert(run.delete)
    end
  end

  # HTTPS Digest authentication
  def test_digest_creds_https
    T2Server::Run.create($uri, WKF_DIGEST_HTTPS, $creds, $conn_params) do |run|
      run.add_password_credential(HEATER_HTTPS, USERNAME, PASSWORD)
      run.add_trust(HEATER_PK)
      run.start
      assert(run.running?)
      assert_nothing_raised(T2Server::RunStateError) { run.wait }
      assert(run.finished?)
      refute(run.output_port("out").error?)
      assert(run.delete)
    end
  end

  # HTTP WS-Security authentication
  def test_ws_creds_http
    T2Server::Run.create($uri, WKF_WS_HTTP, $creds, $conn_params) do |run|
      run.add_password_credential(HEATER_HTTP + WS1, USERNAME, PASSWORD)
      run.add_password_credential(HEATER_HTTP + WS2, USERNAME, PASSWORD)
      run.add_password_credential(HEATER_HTTP + WS3, USERNAME, PASSWORD)
      run.add_password_credential(HEATER_HTTP + WS4, USERNAME, PASSWORD)
      run.start
      assert(run.running?)
      assert_nothing_raised(T2Server::RunStateError) { run.wait }
      assert(run.finished?)
      assert_equal(run.output_port("out_plaintext").value, "Hello Alan!")
      assert_equal(run.output_port("out_digest").value, "Hello Stian!")
      assert_equal(run.output_port("out_plaintext_timestamp").value,
        "Hello Alex!")
      assert_equal(run.output_port("out_digest_timestamp").value,
        "Hello David!")
      assert(run.delete)
    end
  end

  # HTTPS WS-Security authentication
  def test_ws_creds_https
    T2Server::Run.create($uri, WKF_WS_HTTPS, $creds, $conn_params) do |run|
      run.add_password_credential(HEATER_HTTPS + WS1, USERNAME, PASSWORD)
      run.add_password_credential(HEATER_HTTPS + WS2, USERNAME, PASSWORD)
      run.add_password_credential(HEATER_HTTPS + WS3, USERNAME, PASSWORD)
      run.add_password_credential(HEATER_HTTPS + WS4, USERNAME, PASSWORD)
      run.add_trust(HEATER_PK)
      run.start
      assert(run.running?)
      assert_nothing_raised(T2Server::RunStateError) { run.wait }
      assert(run.finished?)
      assert_equal(run.output_port("out_plaintext").value, "Hello Alan!")
      assert_equal(run.output_port("out_digest").value, "Hello Stian!")
      assert_equal(run.output_port("out_plaintext_timestamp").value,
        "Hello Alex!")
      assert_equal(run.output_port("out_digest_timestamp").value,
        "Hello David!")
      assert(run.delete)
    end
  end

  # HTTPS client certificate authentication
  def test_client_cert_auth_https
    T2Server::Run.create($uri, WKF_CLIENT_HTTPS, $creds, $conn_params) do |run|
      run.add_keypair_credential(HEATER_CAUTH, USER_PK, CERTPASS, CERTNAME)
      run.add_trust(HEATER_PK)
      run.start
      assert(run.running?)
      assert_nothing_raised(T2Server::RunStateError) { run.wait }
      assert(run.finished?)
      refute(run.output_port("out").error?)
      assert(run.delete)
    end
  end
end
