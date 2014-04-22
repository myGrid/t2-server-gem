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

class TestServerVersion < Test::Unit::TestCase

  TWO_FOUR = "2.4"
  TWO_FOUR_ZERO = "2.4.0"
  TWO_FOUR_ONE = "2.4.1"
  TWO_FIVE_ZERO = "2.5.0"
  TWO_FIVE_ONE = "2.5.1"

  TWO_FOUR_ZERO_SNAP = "2.4.0-SNAPSHOT"
  TWO_FOUR_ZERO_ALPHA = "2.4.0alpha99"

  def setup
    @v24 = T2Server::Server::Version.new(TWO_FOUR)
    @v240 = T2Server::Server::Version.new(TWO_FOUR_ZERO)
    @v241 = T2Server::Server::Version.new(TWO_FOUR_ONE)
    @v250 = T2Server::Server::Version.new(TWO_FIVE_ZERO)
    @v251 = T2Server::Server::Version.new(TWO_FIVE_ONE)

    @v240s = T2Server::Server::Version.new(TWO_FOUR_ZERO_SNAP)
    @v240a = T2Server::Server::Version.new(TWO_FOUR_ZERO_ALPHA)
  end

  def test_version_parsing
    assert_equal TWO_FOUR_ZERO, @v24.to_s
    assert_equal TWO_FOUR_ZERO, @v240.to_s
    assert_equal TWO_FOUR_ZERO, @v240s.to_s
    assert_equal TWO_FOUR_ZERO, @v240a.to_s
    assert_equal @v24.to_s, @v240.to_s
  end

  def test_version_comparison
    assert @v24 == @v240
    assert @v240 < @v250
    assert @v240 < @v241
    assert @v251 > @v241
    assert @v251 > @v250
  end

  def test_version_components
    assert_equal [2, 4, 0], @v24.to_a
    assert_equal [2, 4, 0], @v240.to_a
    assert_equal [2, 5, 0], @v250.to_a

    assert_equal [2, 4, 0], @v240s.to_a
    assert_equal [2, 4, 0], @v240a.to_a
  end

end
