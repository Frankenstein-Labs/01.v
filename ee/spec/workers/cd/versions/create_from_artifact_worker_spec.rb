# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::Versions::CreateFromArtifactWorker, feature_category: :continuous_delivery do
  let(:image) { 'registry.example.com/group/project/web:latest' }
  let(:source_ref) { 'registry.example.com/group/project/web' }
  let(:data) { { image: image, source_ref: source_ref, organization_id: 1, tag: 'latest', digest: 'sha256:abc' } }
  let(:event) { Cd::ArtifactPublishedEvent.new(data: data) }

  describe '#handle_event' do
    it_behaves_like 'subscribes to event'

    it 'delegates to CreateFromArtifactService with the event payload' do
      expect_next_instance_of(
        ::Cd::Versions::CreateFromArtifactService,
        image: image, source_ref: source_ref, organization_id: 1, tag: 'latest', digest: 'sha256:abc'
      ) do |service|
        expect(service).to receive(:execute)
      end

      consume_event(subscriber: described_class, event: event)
    end
  end
end
