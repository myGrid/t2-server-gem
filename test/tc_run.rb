# Copyright (c) 2010, The University of Manchester, UK.
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

class TestRun < Test::Unit::TestCase

  def test_run
    # connection
    assert_nothing_raised(T2Server::ConnectionError) do
      @run = T2Server::Run.create($address, $wkf_hello)
    end

    # test bad state code
    assert_raise(T2Server::RunStateError) do
      @run.wait
    end

    # test mkdir
    assert(@run.mkdir("test"))

    # start, state and wait
    @run.start
    assert(@run.running?)
    assert_nothing_raised(T2Server::RunStateError) do
      @run.wait
    end

    # exitcode and output
    assert_instance_of(Fixnum, @run.exitcode)
    assert_equal(@run.get_output("Message"), "Hello, World!")
    assert_raise(T2Server::AccessForbiddenError) do
      @run.get_output("wrong!")
    end

    # deletion
    assert(@run.delete)

    # run that need inputs
    @run = T2Server::Run.create($address, $wkf_input)

    assert_nothing_raised(T2Server::AttributeNotFoundError) do
      @run.set_input("input", 10)
    end

    @run.start
    assert(@run.running?)
    assert_nothing_raised(T2Server::RunStateError) do
      @run.wait
    end

    # run that returns list of lists, some empty, using baclava for input
    @run = T2Server::Run.create($address, $wkf_lists)
    assert_nothing_raised(T2Server::AttributeNotFoundError) do
      @run.upload_baclava_file($list_input)
    end
    
    @run.start
    assert(@run.running?)
    assert_nothing_raised(T2Server::RunStateError) do
      @run.wait
    end
    assert_equal(@run.get_output_ports, ["SINGLE", "MANY"])
    assert_equal(@run.get_output("SINGLE"), [])
    assert_equal(@run.get_output("MANY"),
      [[["boo"]], [["", "Hello"]], [], [[], ["test"], []]])

    # run with baclava output
    @run = T2Server::Run.create($address, $wkf_hello)

    assert_nothing_raised(T2Server::AttributeNotFoundError) do
      @run.set_baclava_output
    end

    @run.start
    assert(@run.running?)
    assert_nothing_raised(T2Server::RunStateError) do
      @run.wait
    end

    assert_nothing_raised(T2Server::AttributeNotFoundError) do
      output = @run.get_baclava_output
    end
  end
end
