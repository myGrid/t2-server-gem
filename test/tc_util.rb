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
require 'test/unit'

class TestFilePaths < Test::Unit::TestCase
  def test_path_stripping
    assert_equal("dir/with/child",
      T2Server::Util.strip_path_slashes("dir/with/child"))
    assert_equal("dir/with/child",
      T2Server::Util.strip_path_slashes("/dir/with/child"))
    assert_equal("dir/with/child",
      T2Server::Util.strip_path_slashes("dir/with/child/"))
    assert_equal("dir/with/child",
      T2Server::Util.strip_path_slashes("/dir/with/child/"))

    # only remove one slash from each end
    assert_equal("/dir/with/child/",
      T2Server::Util.strip_path_slashes("//dir/with/child//"))

    # leave double slashes in the middle of paths
    assert_equal("dir/with//child",
      T2Server::Util.strip_path_slashes("/dir/with//child/"))

    # prove it is not stripping in place
    dir = "/dir/with/child/"
    T2Server::Util.strip_path_slashes(dir)
    assert_equal("/dir/with/child/", dir)
  end
end

class TestUriStripping < Test::Unit::TestCase
  def test_uri
    uri = "http://%swww.example.com:8000/path/to/something"
    username = "username"
    password = "password"
    address = uri % "#{username}:#{password}@"

    r_uri, r_creds = T2Server::Util.strip_uri_credentials(address)

    assert_equal(uri % "", r_uri.to_s())
    assert_equal(username, r_creds.username)
  end
end
