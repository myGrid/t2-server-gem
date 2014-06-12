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

require 't2-server'

class TestParams < Test::Unit::TestCase

  CERT_DIR  = "test/workflows/secure"
  SERVER_PK = "#{CERT_DIR}/heater-pk.pem"
  CLNT_CERT = "#{CERT_DIR}/user-cert.p12"
  CLNT_PASS = "testcert"

  def test_base_params
    params = T2Server::ConnectionParameters.new

    params[:verify_peer] = true
    assert_not_nil params[:verify_peer]

    params[:not_a_chance] = true
    assert_nil params[:not_a_chance]
  end

  def test_insecure
    params = T2Server::InsecureSSLConnectionParameters.new

    assert_not_nil params[:verify_peer]
    refute params[:verify_peer]

    assert_nothing_raised do
      T2Server::Server.new("#{$uri}/insecure", params)
    end
  end

  def test_ssl3
    params = T2Server::SSL3ConnectionParameters.new

    assert_not_nil params[:verify_peer]
    assert params[:verify_peer]

    assert_not_nil params[:ssl_version]
    assert_equal :SSLv3, params[:ssl_version]

    assert_nothing_raised do
      T2Server::Server.new("#{$uri}/ssl3", params)
    end
  end

  def test_custom_ca
    uri_suffix = 0

    [CERT_DIR, SERVER_PK, Dir.new(CERT_DIR), File.new(SERVER_PK)].each do |c|
      params = T2Server::CustomCASSLConnectionParameters.new(c)

      assert_not_nil params[:verify_peer]
      assert params[:verify_peer]

      if c.instance_of?(Dir) || File.directory?(c)
        assert_not_nil params[:ca_path]
        assert_equal CERT_DIR, params[:ca_path]
      else
        assert_not_nil params[:ca_file]
        assert_equal SERVER_PK, params[:ca_file]
      end

      assert_nothing_raised do
        T2Server::Server.new("#{$uri}/ca/#{uri_suffix}", params)
      end

      uri_suffix += 1
    end
  end

  def test_client_cert
    uri_suffix = 0

    [CLNT_CERT, File.new(CLNT_CERT)].each do |c|
      params = T2Server::ClientAuthSSLConnectionParameters.new(c, CLNT_PASS)

      assert_not_nil params[:verify_peer]
      assert params[:verify_peer]

      assert_not_nil params[:client_certificate]
      assert_equal CLNT_CERT, params[:client_certificate]
      assert_not_nil params[:client_password]
      assert_equal CLNT_PASS, params[:client_password]

      assert_nothing_raised do
        T2Server::Server.new("#{$uri}/client/#{uri_suffix}", params)
      end

      uri_suffix += 1
    end
  end

end
