# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::Versions::CreateFromArtifactService, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:service_a) { create(:cd_service, application: application, organization: organization) }
  let_it_be(:service_b) { create(:cd_service, application: application, organization: organization) }

  let(:source_ref) { 'registry.example.com/group/project/web' }
  let(:image) { "#{source_ref}:latest" }
  let(:digest) { 'sha256:abc123' }

  let_it_be_with_reload(:source) do
    create(:cd_artifact_source,
      service: service_a, organization: organization, source_ref: 'registry.example.com/group/project/web')
  end

  subject(:execute) do
    described_class.new(
      image: image, source_ref: source_ref, organization_id: organization.id, tag: 'latest', digest: digest
    ).execute
  end

  describe '#execute' do
    it 'creates a version on the matching artifact source' do
      expect { execute }.to change { source.versions.count }.by(1)

      version = source.versions.find_by(name: 'latest')
      expect(version).to have_attributes(
        name: 'latest',
        digest: digest,
        reference: image,
        organization_id: organization.id
      )
    end

    it 'returns the created versions in the payload' do
      response = execute

      expect(response).to be_success
      expect(response.payload[:versions].map(&:name)).to contain_exactly('latest')
    end

    context 'when multiple sources point at the same ref' do
      let_it_be(:other_source) do
        create(:cd_artifact_source,
          service: service_b, organization: organization, source_ref: 'registry.example.com/group/project/web')
      end

      it 'creates a version on every matching source' do
        expect { execute }.to change { Cd::Version.count }.by(2)
      end
    end

    context 'when a source with the same ref belongs to another organization' do
      let_it_be(:other_org) { create(:organization) }
      let_it_be(:other_org_source) do
        other_app = create(:cd_application, organization: other_org)
        other_service = create(:cd_service, application: other_app, organization: other_org)
        create(:cd_artifact_source,
          service: other_service, organization: other_org, source_ref: 'registry.example.com/group/project/web')
      end

      it 'does not create a version outside the pushing organization' do
        expect { execute }.to change { source.versions.count }.by(1)
        expect(other_org_source.versions.reload).to be_empty
      end
    end

    context 'when no source matches the ref' do
      let(:source_ref) { 'registry.example.com/group/project/unknown' }

      it 'creates no versions and succeeds' do
        expect { execute }.not_to change { Cd::Version.count }
        expect(execute).to be_success
      end
    end

    context 'when the same tag is pushed again' do
      before do
        described_class.new(
          image: image, source_ref: source_ref, organization_id: organization.id, tag: 'latest', digest: 'sha256:old'
        ).execute
      end

      it 'updates the existing version instead of creating a duplicate' do
        expect { execute }.not_to change { source.versions.count }
        expect(source.versions.find_by(name: 'latest').digest).to eq(digest)
      end
    end

    context 'when the tag is blank' do
      it 'returns an error and creates nothing' do
        response = described_class.new(
          image: image, source_ref: source_ref, organization_id: organization.id, tag: '', digest: digest
        ).execute

        expect(response).to be_error
        expect(response.reason).to eq(:invalid_artifact)
      end
    end

    context 'when the tag is not a valid CD name' do
      let(:image) { "#{source_ref}:v1.0.0!" }

      let(:service) do
        described_class.new(
          image: image, source_ref: source_ref, organization_id: organization.id, tag: 'v1.0.0!', digest: digest
        )
      end

      it 'skips the invalid version, logs it, and succeeds with an empty payload' do
        expect(::Gitlab::AppLogger).to receive(:info).with(
          hash_including('message' => 'Skipped creating CD version from artifact', 'artifact_source_id' => source.id)
        )

        response = nil
        expect { response = service.execute }.not_to change { Cd::Version.count }

        expect(response).to be_success
        expect(response.payload[:versions]).to be_empty
      end
    end
  end
end
