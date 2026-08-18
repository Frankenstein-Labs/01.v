# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::VersionSets::CreateService, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:current_user) { create(:user) }

  let_it_be(:service) { create(:cd_service, application: application) }
  let_it_be(:artifact_source) { create(:cd_artifact_source, service: service) }
  let_it_be(:version) { create(:cd_version, artifact_source: artifact_source) }

  let(:params) { { name: 'release-1', version_ids: [version.id] } }

  subject(:result) do
    described_class.new(parent: application, current_user: current_user, params: params).execute
  end

  describe '#execute' do
    it 'returns a success response with the persisted version set and its entries', :aggregate_failures do
      expect { result }
        .to change { ::Cd::VersionSet.count }.by(1)
        .and change { ::Cd::VersionSetEntry.count }.by(1)

      version_set = result.payload[:version_set]
      expect(result).to be_success
      expect(version_set).to be_persisted
      expect(version_set).to have_attributes(application: application, organization: organization, name: 'release-1')

      entry = version_set.version_set_entries.first
      expect(entry).to have_attributes(
        version: version,
        artifact_source: artifact_source,
        service: service,
        organization: organization
      )

      expect(version_set.reload.entries_digest).to eq(version_set.compute_entries_digest)
    end

    it 'attributes the version set to the current user' do
      expect(result.payload[:version_set].created_by).to eq(current_user)
    end

    context 'when a description is given' do
      let(:params) { { name: 'release-1', description: 'May production release', version_ids: [version.id] } }

      it 'persists the description' do
        expect(result.payload[:version_set].description).to eq('May production release')
      end
    end

    context 'when an identical version set already exists in the application' do
      before do
        described_class.new(
          parent: application, current_user: current_user,
          params: { name: 'existing', version_ids: [version.id] }
        ).execute
      end

      it 'does not create a duplicate and returns the error' do
        expect { result }
          .to not_change { ::Cd::VersionSet.count }
          .and not_change { ::Cd::VersionSetEntry.count }

        expect(result).to be_error
        expect(result.message).to include('A version set with the same versions already exists in the application')
      end
    end

    context 'when the versions list is empty' do
      let(:params) { { name: 'release-1', version_ids: [] } }

      it 'does not create a version set and returns the error' do
        expect { result }.to not_change { ::Cd::VersionSet.count }

        expect(result).to be_error
        expect(result.message).to include('A version set must contain at least one version')
      end
    end

    context 'when a version does not belong to the application' do
      let_it_be(:other_version) { create(:cd_version) }

      let(:params) { { name: 'release-1', version_ids: [other_version.id] } }

      it 'does not create a version set and returns the error' do
        expect { result }
          .to not_change { ::Cd::VersionSet.count }
          .and not_change { ::Cd::VersionSetEntry.count }

        expect(result).to be_error
        expect(result.message).to include('One or more versions were not found or do not belong to the application')
      end
    end

    context 'when two versions share an artifact source' do
      let_it_be(:other_version) { create(:cd_version, artifact_source: artifact_source) }

      let(:params) { { name: 'release-1', version_ids: [version.id, other_version.id] } }

      it 'does not create a version set and returns the error' do
        expect { result }
          .to not_change { ::Cd::VersionSet.count }
          .and not_change { ::Cd::VersionSetEntry.count }

        expect(result).to be_error
        expect(result.message).to include('Each artifact source can appear only once in a version set')
      end
    end

    context 'when name is blank' do
      let(:params) { { name: '', version_ids: [version.id] } }

      it 'does not create a version set and returns the error' do
        expect { result }.not_to change { ::Cd::VersionSet.count }
        expect(result).to be_error
        expect(result.message).to include("Name can't be blank")
      end
    end

    context 'when name is already taken in the application' do
      before do
        create(:cd_version_set, application: application, name: 'release-1')
      end

      it 'does not create a version set and returns the error' do
        expect { result }.not_to change { ::Cd::VersionSet.count }
        expect(result).to be_error
        expect(result.message).to include('Name has already been taken')
      end
    end

    it 'does not produce N+1 queries beyond per-entry validations as the number of versions grows' do
      versions = create_list(:cd_service, 5, application: application).map do |svc|
        create(:cd_version, artifact_source: create(:cd_artifact_source, service: svc))
      end

      create_version_set('warmup', [versions.first])

      control = ActiveRecord::QueryRecorder.new { create_version_set('control', [versions.second]) }

      uniqueness_checks_per_entry = 2
      threshold = uniqueness_checks_per_entry * (versions.size - 1)

      expect { create_version_set('grown', versions) }
        .not_to exceed_query_limit(control).with_threshold(threshold)
    end
  end

  def create_version_set(name, versions)
    described_class.new(
      parent: application,
      current_user: current_user,
      params: { name: name, version_ids: versions.map(&:id) }
    ).execute
  end
end
