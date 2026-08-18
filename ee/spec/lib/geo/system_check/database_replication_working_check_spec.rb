# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SystemCheck::DatabaseReplicationWorkingCheck, :silence_stdout, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  subject(:database_replication_working_check) { described_class.new }

  describe '#check?' do
    context  'with geo_postgresql_replication_agnostic disabled' do
      before do
        stub_feature_flags(geo_postgresql_replication_agnostic: false)
      end

      it "checks database replication is working" do
        stub_database_state(replication_enabled: false, replication_working: false)

        expect(database_replication_working_check.check?).to be_falsey
      end

      it "returns true when all checks passed" do
        stub_database_state

        expect(database_replication_working_check.check?).to be_truthy
      end
    end

    context 'with geo_postgresql_replication_agnostic feature flag enabled' do
      before do
        stub_feature_flags(geo_postgresql_replication_agnostic: true)
      end

      it "checks database replication enabled without raising error messages" do
        stub_database_state(replication_enabled: false, replication_working: false)

        expect(database_replication_working_check.check?).to be_falsey
      end

      it "returns true when all checks passed" do
        stub_database_state

        expect(database_replication_working_check.check?).to be_truthy
      end
    end
  end

  describe '#skip?' do
    context 'with geo_postgresql_replication_agnostic disabled' do
      before do
        stub_feature_flags(geo_postgresql_replication_agnostic: false)
      end

      it 'returns false when node is not a secondary' do
        primary = create(:geo_node, :primary)
        stub_current_geo_node(primary)
        expect(database_replication_working_check.skip?).to be_truthy
      end
    end

    context 'with geo_postgresql_replication_agnostic feature flag enabled' do
      before do
        stub_feature_flags(geo_postgresql_replication_agnostic: true)
      end

      it 'returns true when replication is not enabled' do
        stub_database_state(replication_enabled: false)

        expect(database_replication_working_check.skip?).to be_truthy
      end
    end
  end

  describe '#show_error' do
    subject(:show_error) { database_replication_working_check.show_error }

    it 'returns an error message' do
      expect(show_error.count).to be 1
      expect(show_error.first).to end_with "/help/administration/geo/setup/database.md"
    end
  end

  describe '#skip_reason' do
    context 'with geo_postgresql_replication_agnostic disabled' do
      before do
        stub_feature_flags(geo_postgresql_replication_agnostic: false)
      end

      it 'returns a message when not a secondary' do
        primary = create(:geo_node, :primary)
        stub_current_geo_node(primary)
        stub_database_state(replication_enabled: false)

        expect(database_replication_working_check.skip_reason).to eq('not a secondary node')
      end
    end

    context 'with geo_postgresql_replication_agnostic enabled' do
      before do
        stub_feature_flags(geo_postgresql_replication_agnostic: true)
      end

      it 'returns a message when replication is not enabled' do
        secondary = create(:geo_node)
        stub_current_geo_node(secondary)
        stub_database_state(replication_enabled: false)

        expect(database_replication_working_check.skip_reason).to eq('database replication is disabled')
      end
    end
  end

  def stub_database_state(replication_enabled: true, replication_working: true)
    allow_next_instance_of(::Gitlab::Geo::HealthCheck) do |health_check|
      allow(health_check).to receive_messages(replication_enabled?: replication_enabled,
        replication_working?: replication_working)
    end
  end
end
