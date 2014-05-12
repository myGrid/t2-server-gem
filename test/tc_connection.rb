# Copyright (c) 2014 The University of Manchester, UK.
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

require 'mocked-server-responses/mocks'
require 't2-server'

class TestConnection < Test::Unit::TestCase
  include T2Server::Mocks

  # Test URIs.
  EXAMPLE_COM = "http://example.com"
  EXAMPLE_COM_S = "https://example.com"
  EXAMPLE_URI = URI.parse(EXAMPLE_COM)
  EXAMPLE_URI_S = URI.parse(EXAMPLE_COM_S)

  def test_bad_connection_addresses
    # Should only pass in URI objects for the address.
    assert_raise(URI::InvalidURIError) do
      T2Server::ConnectionFactory.connect(EXAMPLE_COM, $conn_params)
    end

    # Should only try and handle http(s) schemes.
    bad_scheme = URI.parse("httpx://example.com")
    assert_raise(URI::InvalidURIError) do
      T2Server::ConnectionFactory.connect(bad_scheme, $conn_params)
    end
  end

  def test_bad_connection_params
    assert_raise(ArgumentError) do
      T2Server::ConnectionFactory.connect(EXAMPLE_URI, "wrong")
    end
  end

  def test_no_connection_params
    assert_nothing_raised(ArgumentError) do
      T2Server::ConnectionFactory.connect(EXAMPLE_URI)
    end
  end

  def test_return_same_connection_for_same_address
    conn1 = T2Server::ConnectionFactory.connect(EXAMPLE_URI, $conn_params)
    conn2 = T2Server::ConnectionFactory.connect(EXAMPLE_URI, $conn_params)
    conn3 = T2Server::ConnectionFactory.connect(EXAMPLE_URI_S, $conn_params)
    conn4 = T2Server::ConnectionFactory.connect(EXAMPLE_URI_S, $conn_params)

    assert_same conn1, conn2
    assert_same conn3, conn4
    assert_not_same conn1, conn3
    assert_not_same conn2, conn4
  end

  def test_return_different_connection_for_different_address
    conn1 = T2Server::ConnectionFactory.connect(EXAMPLE_URI, $conn_params)
    conn2 = T2Server::ConnectionFactory.connect(EXAMPLE_URI_S, $conn_params)

    assert_not_same conn1, conn2
  end

  def test_get_404
    mock("", :accept => "*/*", :status => 404)
    connection = T2Server::ConnectionFactory.connect($uri, $conn_params)

    assert_raise(T2Server::AttributeNotFoundError) do
      connection.GET($uri, "*/*", nil, nil)
    end
  end

  def test_put_403
    mock("", :method => :put, :accept => "*/*", :status => 403)

    connection = T2Server::ConnectionFactory.connect($uri, $conn_params)

    assert_raise(T2Server::AccessForbiddenError) do
      connection.PUT($uri, "", "*/*", nil)
    end
  end

  def test_post_401
    mock("", :method => :post, :accept => "*/*", :status => 401)

    connection = T2Server::ConnectionFactory.connect($uri, $conn_params)
    assert_raise(T2Server::AuthorizationError) do
      connection.POST($uri, "", "*/*", nil)
    end
  end

end
