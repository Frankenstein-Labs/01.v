# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SystemCheck::GeoDatabaseConfiguredCheck, :silence_stdout, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  subject(:geo_database_configured_check) { described_class.new }

  after do
    unstub_geo_database_configured
  end

  describe '#multi_check', :reestablished_active_record_base do
    it "checks database configuration" do
      stub_database_state(configured: false)

      expect(geo_database_configured_check).to receive(:try_fixing_it)
                                                 .with(described_class::WRONG_CONFIGURATION_MESSAGE)
      expect(geo_database_configured_check).to receive(:for_more_information)
        .with(described_class::DATABASE_DOCS)
      expect(geo_database_configured_check.multi_check).to be_falsey
    end

    it "checks database configuration" do
      stub_database_state(active: false, select_value: nil)

      expect(geo_database_configured_check).to receive(:try_fixing_it)
                                                 .with(described_class::UNHEALTHY_CONNECTION_MESSAGE)

      expect(geo_database_configured_check.multi_check).to be_falsey
    end

    it "checks table existence" do
      stub_database_state(tables_missing: true)

      expect(geo_database_configured_check).to receive(:try_fixing_it).with(described_class::NO_TABLES_MESSAGE)

      expect(geo_database_configured_check.multi_check).to be_falsey
    end

    it "checks if existing database is being reused" do
      stub_database_state(fresh: false)

      expect(geo_database_configured_check).to receive(:try_fixing_it)
                                                 .with(described_class::REUSING_EXISTING_DATABASE_MESSAGE)
      expect(geo_database_configured_check).to receive(:for_more_information)
        .with(described_class::TROUBLESHOOTING_DOCS)

      expect(geo_database_configured_check.multi_check).to be_falsey
    end

    it "returns true when all checks passed" do
      stub_database_state

      expect(geo_database_configured_check).not_to receive(:try_fixing_it)

      expect(geo_database_configured_check.multi_check).to be_truthy
    end

    it "returns true when select_value works" do
      stub_database_state(active: false)

      expect(geo_database_configured_check).not_to receive(:try_fixing_it)

      expect(geo_database_configured_check.multi_check).to be_truthy
    end
  end

  def stub_database_state(configured: true, active: true, tables_missing: false, fresh: true, select_value: 1)
    allow(::Gitlab::Geo).to receive(:geo_database_configured?).and_return(configured)
    allow(::Geo::TrackingBase).to receive_message_chain(:connection, :active?).and_return(active)

    pending_migrations = tables_missing ? [Struct.new('Migration', :version).new('20250101000000')] : []

    allow(::Geo::TrackingBase).to receive_message_chain(:connection, :pool, :migration_context, :migrations)
                                    .and_return(pending_migrations)
    allow(::Geo::TrackingBase::SchemaMigration).to receive(:table_exists?).and_return(false)

    if select_value == 1
      allow(::Geo::TrackingBase).to receive_message_chain(:connection, :select_value).and_return(select_value)
    else
      allow(::Geo::TrackingBase).to receive_message_chain(:connection, :active?).and_raise(PG::ConnectionBad)
    end

    allow_next_instance_of(::Gitlab::Geo::HealthCheck) do |health_check|
      allow(health_check).to receive(:reusing_existing_tracking_database?).and_return(!fresh)
    end
  end
end
