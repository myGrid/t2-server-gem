# Copyright (c) 2010-2013 The University of Manchester, UK.
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

# :stopdoc:
module T2Server

  class Server

    # This class is used to cache Run objects in a Server so they don't need to
    # be created so often. When manipulating this cache the user credentials
    # should be passed in, or the global user ":all" will be used instead.
    class RunCache

      def initialize(server)
        @server = server
        @cache = {}
      end

      # Add a run, or runs, to the cache.
      def add_run(runs, credentials = nil)
        cache = user_cache(credentials)

        [*runs].each do |run|
          cache[run.id] = run
        end
      end

      # This method adds all new runs (creating instances where required) in
      # the list provided AND removes any runs no longer in the list.
      def refresh_all!(run_list, credentials = nil)
        cache = user_cache(credentials)

        # Add new runs to the user cache.
        run_list.each_key do |id|
          if !cache.has_key? id
            cache[id] = Run.create(@server, "", credentials, run_list[id])
          end
        end

        # Clear out the expired runs.
        if cache.length > run_list.length
          cache.delete_if {|key, _| !run_list.member? key}
        end

        cache
      end

      # Delete all runs objects from the cache. This does not delete runs from
      # the remote server - just their locally cached instances.
      def clear!(credentials = nil)
        user_cache(credentials).clear
      end

      # Get all the specified user's runs.
      def runs(credentials = nil)
        user_cache(credentials)
      end

      private

      def user_cache(credentials)
        user = credentials.nil? ? :all : credentials.username
        @cache[user] ||= {}
      end

    end

  end
end
# :startdoc:
