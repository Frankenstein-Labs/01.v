# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SystemCheck::DatabaseReplicationEnabledCheck, :silence_stdout, feature_category: :geo_replication do
  subject(:database_replication_enabled_check) { described_class.new }

  describe '#check?' do
    context  'with geo_postgresql_replication_agnostic disabled' do
      before do
        stub_feature_flags(geo_postgresql_replication_agnostic: false)
      end

      it "returns false when replication is disabled" do
        stub_database_state(replication_enabled: false)

        expect(database_replication_enabled_check.check?).to be_falsey
      end

      it "returns true when replication is enabled" do
        stub_database_state

        expect(database_replication_enabled_check.check?).to be_truthy
      end
    end

    context 'with geo_postgresql_replication_agnostic enabled' do
      before do
        stub_feature_flags(geo_postgresql_replication_agnostic: true)
      end

      it "returns false when replication is disabled" do
        stub_database_state(replication_enabled: false)

        expect(database_replication_enabled_check.check?).to be_falsey
      end

      it "returns true when replication is enabled" do
        stub_database_state

        expect(database_replication_enabled_check.check?).to be_truthy
      end
    end
  end

  describe '#show_error' do
    context 'with geo_postgresql_replication_agnostic disabled' do
      before do
        stub_feature_flags(geo_postgresql_replication_agnostic: false)
      end

      it 'shows errors when replication is disabled' do
        stub_database_state(replication_enabled: false)

        expect(database_replication_enabled_check).to receive(:try_fixing_it)
        expect(database_replication_enabled_check).to receive(:for_more_information)

        database_replication_enabled_check.show_error
      end
    end

    context 'with geo_postgresql_replication_agnostic enabled' do
      before do
        stub_feature_flags(geo_postgresql_replication_agnostic: true)
      end

      it 'does not show errors when replication is disabled' do
        stub_database_state(replication_enabled: false)

        expect(database_replication_enabled_check).not_to receive(:try_fixing_it)
        expect(database_replication_enabled_check).not_to receive(:for_more_information)

        database_replication_enabled_check.show_error
      end
    end
  end

  def stub_database_state(replication_enabled: true)
    allow_next_instance_of(::Gitlab::Geo::HealthCheck) do |health_check|
      allow(health_check).to receive(:replication_enabled?).and_return(replication_enabled)
    end
  end
end
