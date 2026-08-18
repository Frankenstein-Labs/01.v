# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillSecurityScanProfilesNameAndDesc, feature_category: :security_asset_inventories do
  let(:organizations_table) { table(:organizations) }
  let(:namespaces_table) { table(:namespaces) }
  let(:security_scan_profiles_table) { table(:security_scan_profiles, database: :sec) }

  let(:organization) { organizations_table.create!(name: 'organization', path: 'organization') }
  let(:group) do
    namespaces_table.create!(name: 'group', path: 'group', type: 'Group', organization_id: organization.id)
  end

  let(:secret_detection_scan_type) { 1 }
  let(:sast_scan_type) { 0 }

  let(:expected_name) { described_class::DEFAULT_PROFILE_NAME }
  let(:expected_description) { described_class::DEFAULT_PROFILE_DESCRIPTION }

  let!(:default_secret_detection_profile) do
    security_scan_profiles_table.create!(
      namespace_id: group.id,
      scan_type: secret_detection_scan_type,
      gitlab_recommended: true,
      name: 'Old Name',
      description: 'Old Description'
    )
  end

  let!(:custom_secret_detection_profile) do
    security_scan_profiles_table.create!(
      namespace_id: group.id,
      scan_type: secret_detection_scan_type,
      gitlab_recommended: false,
      name: 'Custom Name',
      description: 'Custom Description'
    )
  end

  let!(:sast_profile) do
    security_scan_profiles_table.create!(
      namespace_id: group.id,
      scan_type: sast_scan_type,
      gitlab_recommended: true,
      name: 'SAST Profile',
      description: 'SAST Description'
    )
  end

  let(:migration_instance) do
    described_class.new(
      start_id: security_scan_profiles_table.minimum(:id),
      end_id: security_scan_profiles_table.maximum(:id),
      batch_table: :security_scan_profiles,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: SecApplicationRecord.connection
    )
  end

  subject(:perform_migration) { migration_instance.perform }

  describe '#perform' do
    it 'updates gitlab_recommended secret_detection profiles' do
      expect { perform_migration }
        .to change { default_secret_detection_profile.reload.name }.to(expected_name)
        .and change { default_secret_detection_profile.reload.description }.to(expected_description)
    end

    it 'does not update custom secret_detection profiles' do
      expect { perform_migration }
        .to not_change { custom_secret_detection_profile.reload.name }
        .and not_change { custom_secret_detection_profile.reload.description }
    end

    it 'does not update non-secret_detection profiles' do
      expect { perform_migration }
        .to not_change { sast_profile.reload.name }
        .and not_change { sast_profile.reload.description }
    end
  end
end
