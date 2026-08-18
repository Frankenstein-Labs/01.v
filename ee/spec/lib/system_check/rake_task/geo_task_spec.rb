# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemCheck::RakeTask::GeoTask, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let(:common_checks) do
    [
      Geo::SystemCheck::LicenseCheck,
      Geo::SystemCheck::EnabledCheck,
      Geo::SystemCheck::CurrentNodeCheck,
      Geo::SystemCheck::GeoDatabasePromotedCheck,
      Geo::SystemCheck::ClocksSynchronizationCheck,
      SystemCheck::App::GitUserDefaultSSHConfigCheck,
      Geo::SystemCheck::AuthorizedKeysCheck,
      Geo::SystemCheck::AuthorizedKeysFlagCheck,
      SystemCheck::App::HashedStorageEnabledCheck,
      SystemCheck::App::HashedStorageAllProjectsCheck,
      Geo::SystemCheck::ContainerRegistryCheck
    ]
  end

  let(:secondary_checks) do
    [
      Geo::SystemCheck::GeoDatabaseConfiguredCheck,
      Geo::SystemCheck::DatabaseReplicationEnabledCheck,
      Geo::SystemCheck::DatabaseReplicationWorkingCheck,
      Geo::SystemCheck::DatabaseMigrationCheck,
      Geo::SystemCheck::HttpConnectionCheck,
      Geo::SystemCheck::SshPortCheck
    ] + common_checks
  end

  let(:org_migration_target_checks) do
    [
      Geo::SystemCheck::HttpConnectionCheck
    ] + common_checks
  end

  describe '.checks' do
    context 'when geo_nodes table does not exist' do
      before do
        allow(GeoNode.connection).to receive(:table_exists?).with(:geo_nodes).and_return(false)
      end

      it 'returns only the GeoNodesCheck' do
        expect(described_class.checks).to eq([Geo::SystemCheck::GeoNodesCheck])
      end
    end

    context 'when geo_nodes table exists' do
      before do
        allow(GeoNode.connection).to receive(:table_exists?).with(:geo_nodes).and_return(true)
      end

      context 'primary node' do
        it 'secondary checks is skipped' do
          primary = create(:geo_node, :primary)
          stub_current_geo_node(primary)

          expect(described_class.checks).to eq(common_checks)
        end
      end

      context 'secondary node' do
        it 'secondary checks is called' do
          secondary = create(:geo_node)
          stub_current_geo_node(secondary)

          expect(described_class.checks).to eq(secondary_checks)
        end
      end

      context 'org migration target node' do
        it 'org migration target checks is called' do
          stub_org_migration_target_cell

          checks = described_class.checks

          expect(checks).to eq(org_migration_target_checks)
          expect(checks).not_to include(Geo::SystemCheck::DatabaseReplicationWorkingCheck)
        end
      end

      context 'Geo disabled' do
        it 'secondary checks is skipped' do
          expect(described_class.checks).to eq(common_checks)
        end
      end

      context 'Geo is enabled but node is not identified' do
        it 'secondary checks is called' do
          create(:geo_node)
          stub_geo_nodes_exist_but_none_match_current_node

          expect(described_class.checks).to eq(secondary_checks)
        end
      end
    end
  end
end
