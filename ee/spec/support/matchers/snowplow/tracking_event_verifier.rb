# frozen_string_literal: true

module Matchers
  module Snowplow
    def self.clean_snowplow_queue
      return unless Gitlab::Tracking.micro_verification_enabled?

      # http://localhost:9090/micro/reset
      Gitlab::HTTP
        .try_get("#{Gitlab::Tracking::Destinations::SnowplowMicro.new.uri}/micro/reset", allow_local_requests: true)
    end

    def have_all_expected_events
      TrackingEventVerifier.new
    end

    class TrackingEventVerifier
      def matches?(events_key)
        return true unless Gitlab::Tracking.micro_verification_enabled?

        load_file_contents(events_key)

        flush_remaining_events
        fetch_results

        process_page_view_events
        process_structured_events

        not_found_page_view_events.empty? && not_found_structured_events.empty?
      end

      def failure_message
        suffix_msg = "to be found in tracking results and were not"

        final_message = ''

        if not_found_page_view_events.present?
          final_message = "expected page view events #{not_found_page_view_events.inspect} #{suffix_msg}.\n"
        end

        if not_found_structured_events.present?
          final_message += "expected structured events #{not_found_structured_events.inspect} #{suffix_msg}.\n"
        end

        final_message
      end

      private

      attr_reader :page_view_events, :structured_events, :results, :not_found_page_view_events,
        :not_found_structured_events

      def load_file_contents(events_key)
        file_name = "#{events_key}.yml"
        file_contents = YAML.safe_load(
          File.read(Rails.root.join('ee/spec/fixtures/snowplow/tracking_verification', file_name))
        )
        @structured_events = file_contents.fetch('structured_events', [])
        @page_view_events = file_contents.fetch('page_view_events', [])
        @not_found_page_view_events = page_view_events.dup
        @not_found_structured_events = structured_events.dup
      end

      def flush_remaining_events
        # one last non-async flush just in case anything is left in the buffer(though we are set to 1 for buffer_size)
        ::Gitlab::Tracking.flush
      end

      def fetch_results
        # http://localhost:9090/micro/good
        # take the above output and verify it vs some predefined json/yml
        # maybe some validation against all too for brokenness
        # RestClient.get('http://localhost:9090/micro/good') # parse it against what we expect to see
        @results = Gitlab::HTTP.try_get(
          "#{Gitlab::Tracking::Destinations::SnowplowMicro.new.uri}/micro/good", allow_local_requests: true
        )
      end

      def process_page_view_events
        page_view_events.each do |page_view_event|
          verify_page_view_event(page_view_event)
        end
      end

      def verify_page_view_event(page_view_event)
        results.select { |r, _v| r['eventType'] == 'page_view' }.each do |e|
          # fuzzy this a bit initially since we have project/group in path /namespace97/project31/-/learn_gitlab
          if e.dig('event', 'page_urlpath').match?(/#{page_view_event}\z/)
            @not_found_page_view_events.delete(page_view_event)
          end
        end
      end

      def process_structured_events
        structured_events.each do |structured_event|
          verify_structured_event(structured_event)
        end
      end

      def verify_structured_event(structured_event)
        results.select { |r, _v| r['eventType'] == 'struct' }.each do |result_event|
          next unless structured_event_found?(result_event, structured_event)

          @not_found_structured_events.delete(structured_event)
        end
      end

      def structured_event_found?(result_event, structured_event)
        found = false

        %w[category action label property value].each do |field|
          next unless structured_event[field].present?

          found = result_event.dig('event', "se_#{field}") == structured_event[field]

          break unless found
        end

        found
      end
    end
  end
end
