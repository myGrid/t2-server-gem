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

require 'webmock/test_unit'

module T2Server
  module Mocks

    def mock(path, options = {})
      options = { :method => :get, :accept => "*/*", :status => 200 }.merge(options)

      with = { :headers => { "Accept" => options[:accept] } }
      with[:body] = options[:body] if options[:body]

      output =
      if options[:output]
        file(options[:output])
      else
        out = add_to_hash(:status, options[:status])
        out = add_to_hash("Location", options[:location], out, true) if options[:location]
        out
      end

      stub_request(options[:method], uri(options[:credentials]) + path).
        with(with).to_return(output)
    end

    private

    def add_to_hash(param, values, hash = [], headers = false)
      values = [*values]

      hi = 0
      values.each do |v|
        hash[hi] ||= {}

        if headers
          hash[hi][:headers] ||= {}
          hash[hi][:headers][param] = v
        else
          hash[hi][param] = v
        end

        hi += 1
      end

      hash
    end

    def uri(credentials)
      if credentials.nil?
        $uri.to_s
      else
        u = $uri.dup
        u.userinfo = credentials
        u.to_s
      end
    end

    def file(name)
      File.new(File.join(File.dirname(__FILE__), name))
    end

  end
end
