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

require 't2-server'

class TestCredentials < Test::Unit::TestCase

  USERNAME = "username"
  PASSWORD = "password"
  USERINFO = "#{USERNAME}:#{PASSWORD}"

  # This class is used to ensure that the password is set in the credentials.
  class FakeRequest
    def basic_auth(user, pass)
      pass
    end
  end

  def test_no_password_exposure
    creds = T2Server::HttpBasic.new(USERNAME, PASSWORD)

    r_to_s = creds.to_s
    r_inspect = creds.inspect

    refute r_to_s.include?(PASSWORD)
    refute r_inspect.include?(PASSWORD)
  end

  def test_create_basic
    request = FakeRequest.new
    creds = T2Server::HttpBasic.new(USERNAME, PASSWORD)

    assert_equal USERNAME, creds.username
    assert_equal PASSWORD, creds.authenticate(request)
  end

  def test_parse_basic
    request = FakeRequest.new
    creds = T2Server::HttpBasic.parse(USERINFO)

    assert_equal USERNAME, creds.username
    assert_equal PASSWORD, creds.authenticate(request)
  end
end
