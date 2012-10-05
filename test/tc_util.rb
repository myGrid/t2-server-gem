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

class TestUriPathAppending < Test::Unit::TestCase
  def test_append
    original = URI.parse("http://www.example.com:8080/old")
    original_copy = URI.parse("http://www.example.com:8080/old")
    extra_path = "new/bit"
    blank_path = ""
    appended = URI.parse("http://www.example.com:8080/old/new/bit")

    # Prove it works.
    assert_equal(appended, T2Server::Util.append_to_uri_path(original, extra_path))
    assert_equal(original, T2Server::Util.append_to_uri_path(original, blank_path))

    # Make sure the original is not changed!
    assert_equal(original, original_copy)
  end
end

class TestUriPathReplacement < Test::Unit::TestCase
  def test_replace
    original = URI.parse("http://www.example.com:8080/old/path")
    original_copy = URI.parse("http://www.example.com:8080/old/path")
    new_path = "/new/path"
    replaced = URI.parse("http://www.example.com:8080/new/path")

    # Prove it works.
    assert_equal(replaced, T2Server::Util.replace_uri_path(original, new_path))

    # Make sure the original is not changed!
    assert_equal(original, original_copy)
  end
end

class TestGetUriPathLeaf < Test::Unit::TestCase
  def test_get_leaf
    uri1 = URI.parse("http://www.example.com:8080/old/path")
    uri2 = URI.parse("http://www.example.com:8080/")
    uri3 = URI.parse("http://www.example.com:8080")

    assert_equal("path", T2Server::Util.get_path_leaf_from_uri(uri1))
    assert_equal("", T2Server::Util.get_path_leaf_from_uri(uri2))
    assert_equal("", T2Server::Util.get_path_leaf_from_uri(uri3))
  end
end
