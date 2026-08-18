# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class ProcessInvalidEnabledNamespaceEvent < ::Gitlab::EventStore::Event
        def schema
          {
            'type' => 'object',
            'properties' => {
              'last_processed_id' => { 'type' => %w[integer null] }
            },
            'additionalProperties' => false
          }
        end
      end
    end
  end
end
