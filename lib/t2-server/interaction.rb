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

require 'atom'
require 'uri'

module T2Server

  # The Interaction module provides access to Taverna workflow notifications
  # as supplied by the Interaction Service. These are read from an Atom feed
  # and returned as Notification objects. For more information about the
  # Interaction Service, see
  # http://dev.mygrid.org.uk/wiki/display/taverna/Interaction+service
  module Interaction

    # :stopdoc:
    FEED_NS = "http://ns.taverna.org.uk/2012/interaction"

    class Feed
      def initialize(run)
        @run = run
        @cache = {:requests => {}, :replies => {}}
      end

      # Get all new notification requests since they were last checked.
      #
      # Here we really only want new unanswered notifications, but polling
      # returns all requests new to *us*, even those that have been replied to
      # elsewhere. Filter out answered requests here.
      def new_requests
        poll(:requests).select { |i| !i.has_reply? }
      end

      # Get all notifications, or all of a particular type.
      def notifications(type = :all)
        poll

        case type
        when :requests, :replies
          @cache[type].values
        else
          @cache[:requests].values + @cache[:replies].values
        end
      end

      private

      def entries(&block)
        feed = Atom::Feed.load_feed(@run.read_notification_feed)
        feed.each_entry(:paginate => true, &block)
      end

      # Poll for all notification types and update the caches.
      #
      # Returns any new notifications, [] otherwise. If you are only
      # interested in knowing about new notifications of a specific type you
      # can use the type parameter to specify this. Use :requests, :replies or
      # :all (default).
      def poll(type = :all)
        updates = []
        requests = @cache[:requests]
        replies = @cache[:replies]

        entries do |entry|
          # It's worth noting what happens here.
          #
          # This connection to a run's notification feed may not be the only
          # one, or it might be a reconnection. As a result we might see a
          # reply before we see the original request; atom feeds are last in
          # first out.
          #
          # So if we see a reply, we should check to see if we have the
          # request before setting the request to "replied". And if we see a
          # request we should check to see if we have a reply for it already;
          # we may have seen the reply the previous time through the loop.
          note = Notification.new(entry, @run)
          if note.is_reply?
            next if replies.has_key? note.reply_to
            requests[note.reply_to].has_reply unless requests[note.reply_to].nil?
            replies[note.reply_to] = note
            updates << note if type == :replies || type == :all
          else
            next if requests.has_key? note.id
            note.has_reply unless replies[note.id].nil?
            requests[note.id] = note
            updates << note if type == :requests || type == :all
          end
        end

        updates
      end

    end
    # :startdoc:

    # This class represents a Taverna notification.
    class Notification

      # The identifier of this notification.
      attr_reader :id

      # If this notification is a reply then this is the identifier of the
      # notification that it is a reply to.
      attr_reader :reply_to

      # The URI of the notification page to show.
      attr_reader :uri

      # The serial number of a notification. This identifies a notification
      # within a workflow.
      attr_reader :serial

      # :stopdoc:
      def initialize(entry, run)
        @run = run
        reply_to = entry[FEED_NS, "in-reply-to"]
        if reply_to.empty?
          @is_reply = false
          @has_reply = false
          @id = entry[FEED_NS, "id"][0]
          @is_notification = entry[FEED_NS, "progress"].empty? ? false : true
          @uri = get_link(entry.links)
          @serial = "#{entry[FEED_NS, 'path'][0]}-#{entry[FEED_NS, 'count'][0]}"
        else
          @is_reply = true
          @is_notification = false
          @reply_to = reply_to[0]
        end
      end
      # :startdoc:

      # :call-seq:
      #   is_reply? -> true or false
      #
      # Is this notification a reply to another notification?
      def is_reply?
        @is_reply
      end

      # :call-seq:
      #   is_notification? -> true or false
      #
      # Is this notification a pure notification only? There is no user
      # response to a pure notification, it is for information only.
      def is_notification?
        @is_notification
      end

      # :stopdoc:
      def has_reply
        @has_reply = true
      end
      # :startdoc:

      # :call-seq:
      #   has_reply? -> true or false
      #
      # Does this notification have a reply? This only makes sense for
      # notifications that are not replies or pure notifications.
      def has_reply?
        @has_reply
      end

      # :call-seq:
      #   input_data -> data
      #
      # Get the input data associated with this notification. Returns an empty
      # string if this notification is a reply.
      def input_data
        return "" if is_reply?

        data_name = "interaction#{@id}InputData.json"
        @run.read_interaction_data(data_name)
      rescue AttributeNotFoundError
        # It does not matter if the file doesn't exist.
        ""
      end

      # :call-seq:
      #   reply(status, data)
      #
      # Given a status and some data this method uploads the data and
      # publishes an interaction reply on the run's notification feed.
      def reply(status, data)
        data_name = "interaction#{@id}OutputData.json"

        notification = Atom::Entry.new do |entry|
          entry.title = "A reply to #{@id}"
          entry.id = "#{@id}reply"
          entry.content = ""
          entry[FEED_NS, "run-id"] << @run.id
          entry[FEED_NS, "in-reply-to"] << @id
          entry[FEED_NS, "result-status"] << status
        end.to_xml

        @run.write_interaction_data(data_name, data)
        @run.write_notification(notification)
      end

      private

      def get_link(links)
        links.each do |l|
          return URI.parse(l.to_s) if l.rel == "presentation"
        end
      end
    end

  end

end
