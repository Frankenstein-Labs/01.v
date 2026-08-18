# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::ArtifactSources::PublishFromRegistryWorker, feature_category: :continuous_delivery do
  let_it_be(:project) { create(:project) }

  let(:source_ref) { 'registry.example.com/group/project/web' }
  let(:image) { "#{source_ref}:latest" }
  let(:data) do
    { project_id: project.id, image: image, repository: source_ref, tag: 'latest', digest: 'sha256:abc' }
  end

  let(:event) { ContainerRegistry::ImagePushedEvent.new(data: data) }

  describe '#handle_event' do
    it_behaves_like 'subscribes to event'

    it 'publishes a Cd::ArtifactPublishedEvent carrying the artifact identity and organization' do
      expect { consume_event(subscriber: described_class, event: event) }
        .to publish_event(::Cd::ArtifactPublishedEvent)
          .with(
            image: image,
            source_ref: source_ref,
            organization_id: project.organization_id,
            tag: 'latest',
            digest: 'sha256:abc',
            published_at: kind_of(String)
          )
    end

    it 'does not publish when the project no longer exists' do
      event.data[:project_id] = non_existing_record_id

      expect { consume_event(subscriber: described_class, event: event) }
        .not_to publish_event(::Cd::ArtifactPublishedEvent)
    end
  end

  describe '.dispatch?' do
    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(ai_native_deploy: false)
      end

      it 'returns false' do
        expect(described_class.dispatch?(event)).to be(false)
      end
    end

    context 'when the feature flag is enabled' do
      it 'returns true when tag and digest are present' do
        expect(described_class.dispatch?(event)).to be(true)
      end

      it 'returns false when the tag is missing' do
        event.data.delete(:tag)

        expect(described_class.dispatch?(event)).to be(false)
      end

      it 'returns false when the digest is missing' do
        event.data.delete(:digest)

        expect(described_class.dispatch?(event)).to be(false)
      end

      it 'returns false when the repository is missing' do
        event.data.delete(:repository)

        expect(described_class.dispatch?(event)).to be(false)
      end
    end
  end
end
