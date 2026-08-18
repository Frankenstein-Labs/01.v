# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillSdSecurityScanProfilesTriggers, feature_category: :security_asset_inventories do
  let(:organizations_table) { table(:organizations) }
  let(:namespaces_table) { table(:namespaces) }
  let(:scan_profiles_table) { table(:security_scan_profiles, database: :sec) }
  let(:triggers_table) { table(:security_scan_profile_triggers, database: :sec) }

  let(:organization) { organizations_table.create!(name: 'organization', path: 'organization') }
  let(:group) do
    namespaces_table.create!(name: 'group', path: 'group', type: 'Group', organization_id: organization.id)
  end

  let(:default_branch_pipeline_trigger) { 0 }
  let(:merge_request_pipeline_trigger) { 1 }

  let!(:default_sd_profile) do
    scan_profiles_table.create!(namespace_id: group.id, scan_type: 1, gitlab_recommended: true, name: 'SD default')
  end

  let!(:custom_sd_profile) do
    scan_profiles_table.create!(namespace_id: group.id, scan_type: 1, gitlab_recommended: false, name: 'SD custom')
  end

  let!(:sast_profile) do
    scan_profiles_table.create!(namespace_id: group.id, scan_type: 0, gitlab_recommended: true, name: 'SAST')
  end

  let(:migration_instance) do
    described_class.new(
      start_id: scan_profiles_table.minimum(:id),
      end_id: scan_profiles_table.maximum(:id),
      batch_table: :security_scan_profiles,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: SecApplicationRecord.connection
    )
  end

  subject(:perform_migration) { migration_instance.perform }

  def triggers_for(profile)
    triggers_table.where(security_scan_profile_id: profile.id)
  end

  describe '#perform' do
    it 'creates both trigger types for gitlab_recommended secret_detection profiles' do
      expect { perform_migration }.to change { triggers_table.count }.from(0).to(2)

      expect(triggers_for(default_sd_profile).pluck(:trigger_type)).to contain_exactly(
        default_branch_pipeline_trigger,
        merge_request_pipeline_trigger
      )
      expect(triggers_for(default_sd_profile).pluck(:namespace_id)).to all(eq(group.id))
    end

    it 'does not create triggers for non-matching profiles' do
      perform_migration

      expect(triggers_for(custom_sd_profile)).to be_empty
      expect(triggers_for(sast_profile)).to be_empty
    end

    context 'when triggers already exist' do
      before do
        triggers_table.create!(
          security_scan_profile_id: default_sd_profile.id,
          namespace_id: group.id,
          trigger_type: default_branch_pipeline_trigger
        )
      end

      it 'only creates missing triggers' do
        expect { perform_migration }.to change { triggers_table.count }.from(1).to(2)
        expect(triggers_for(default_sd_profile).pluck(:trigger_type)).to contain_exactly(
          default_branch_pipeline_trigger,
          merge_request_pipeline_trigger
        )
      end
    end

    context 'when no matching profiles exist in the batch' do
      let(:migration_instance) do
        described_class.new(
          start_id: custom_sd_profile.id,
          end_id: custom_sd_profile.id,
          batch_table: :security_scan_profiles,
          batch_column: :id,
          sub_batch_size: 100,
          pause_ms: 0,
          connection: SecApplicationRecord.connection
        )
      end

      it 'does not create any triggers' do
        expect { perform_migration }.not_to change { triggers_table.count }
      end
    end
  end
end
