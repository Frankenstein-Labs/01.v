# frozen_string_literal: true

module Gitlab
  module Audit
    module Events
      class Preloader
        def self.preload!(audit_events)
          audit_events.tap do |audit_events|
            audit_events.each do |audit_event|
              audit_event.lazy_author
              audit_event.entity
            end
          end
        end

        def initialize(audit_events)
          @audit_events = audit_events
        end

        def find_each(&block)
          @audit_events.each_batch(column: :created_at) do |relation|
            # rubocop:disable Style/CombinableLoops -- BatchLoader must preload all associated records before yielding (https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169977#note_2175391750)
            relation.each do |audit_event|
              audit_event.lazy_author
              audit_event.entity
            end

            relation.each do |audit_event|
              yield(audit_event)
            end
            # rubocop:enable Style/CombinableLoops

            BatchLoader::Executor.clear_current
          end
        end
      end
    end
  end
end
