# frozen_string_literal: true

module Cd
  # rubocop:disable Gitlab/EventStoreCloudEventInheritance -- system-originated artifact event with no user actor; mirrors ContainerRegistry::ImagePushedEvent
  class ArtifactPublishedEvent < ::Gitlab::EventStore::Event
    # rubocop:enable Gitlab/EventStoreCloudEventInheritance
    def schema
      {
        'type' => 'object',
        'required' => %w[image source_ref digest organization_id tag],
        'properties' => {
          'image' => { 'type' => 'string' },
          'source_ref' => { 'type' => 'string' },
          'digest' => { 'type' => 'string' },
          'organization_id' => { 'type' => 'integer' },
          'tag' => { 'type' => 'string' },
          'published_at' => { 'type' => 'string', 'format' => 'date-time' }
        }
      }
    end
  end
end
