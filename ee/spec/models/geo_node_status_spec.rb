# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GeoNodeStatus, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  using RSpec::Parameterized::TableSyntax

  # freeze: true prevents accidental mutation of shared records across examples,
  # catching state leakage that causes flaky tests. See https://gitlab.com/gitlab-org/gitlab/-/issues/590041
  let_it_be(:primary, freeze: true) { create(:geo_node, :primary) }
  let_it_be(:secondary, freeze: true) { create(:geo_node, :secondary) }
  let_it_be(:group, freeze: true)     { create(:group) }
  let_it_be_with_reload(:project_1) { create(:project, group: group) }
  let_it_be_with_reload(:project_2) { create(:project, group: group) }
  let_it_be(:project_3, freeze: true) { create(:project) }
  let_it_be(:project_4, freeze: true) { create(:project) }

  subject(:status) { described_class.current_node_status }

  before do
    # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
    # is not allowed within a transaction but all RSpec tests run inside of a transaction.
    stub_batch_counter_transaction_open_check
    stub_current_geo_node(secondary)

    primary.reload_status
    secondary.reload_status
  end

  describe '#fast_current_node_status' do
    it 'reads the cache and spawns the worker' do
      expect(described_class).to receive(:spawn_worker).once

      rails_cache = double
      expect(rails_cache).to receive(:read).with(described_class.cache_key)
      expect(Rails).to receive(:cache).and_return(rails_cache)

      described_class.fast_current_node_status
    end
  end

  describe '#update_cache!' do
    it 'writes a cache' do
      status = described_class.new

      rails_cache = double
      allow(Rails).to receive(:cache).and_return(rails_cache)

      expect(rails_cache).to receive(:write).with(described_class.cache_key, kind_of(Hash))

      status.update_cache!
    end
  end

  describe '#for_active_secondaries' do
    it 'excludes primaries and disabled nodes' do
      create(:geo_node_status, geo_node: primary)
      create(:geo_node_status, geo_node: create(:geo_node, :secondary, enabled: false))
      enabled_secondary_status = create(:geo_node_status, geo_node: create(:geo_node, :secondary, enabled: true))

      expect(described_class.for_active_secondaries).to match_array([enabled_secondary_status])
    end
  end

  describe '#healthy?' do
    context 'when health is blank' do
      it 'returns true' do
        status.status_message = ''

        expect(status.healthy?).to be true
      end
    end

    context 'when health is present' do
      it 'returns true' do
        status.status_message = GeoNodeStatus::HEALTHY_STATUS

        expect(status.healthy?).to be true
      end

      it 'returns false' do
        status.status_message = 'something went wrong'

        expect(status.healthy?).to be false
      end
    end

    context 'with outdated? taken into consideration' do
      it 'return false' do
        status.status_message = GeoNodeStatus::HEALTHY_STATUS
        status.updated_at = 61.minutes.ago

        expect(status.healthy?).to be false
      end

      it 'return false' do
        status.status_message = 'something went wrong'
        status.updated_at = 1.minute.ago

        expect(status.healthy?).to be false
      end
    end
  end

  describe '#outdated?' do
    it 'return true' do
      status.updated_at = 61.minutes.ago

      expect(status.outdated?).to be true
    end

    it 'return false' do
      status.updated_at = 1.minute.ago

      expect(status.outdated?).to be false
    end
  end

  describe '#status_message' do
    it 'delegates to the HealthCheck' do
      expect(HealthCheck::Utils).to receive(:process_checks).with(['geo']).once

      status
    end
  end

  describe '#health' do
    stale_status_message = format(
      'Geo node status has not been updated in over %{minutes} minutes. Site status may be stale.',
      minutes: GeoNodeStatus::EXPIRATION_IN_MINUTES
    )

    where(:status_message, :outdated, :expected_health_message) do
      'something went wrong' | true  | 'something went wrong'
      'something went wrong' | false | 'something went wrong'
      ''                     | true  | stale_status_message
      ''                     | false | nil
    end

    with_them do
      it 'returns the expected health message' do
        status.status_message = status_message
        status.updated_at = outdated ? 61.minutes.ago : 1.minute.ago

        expect(status.health).to eq(expected_health_message)
      end
    end
  end

  describe '#db_replication_lag_seconds' do
    context 'when in a secondary node' do
      before do
        allow(Gitlab::Geo).to receive(:secondary?).and_return(true)
        allow(Gitlab::Geo::HealthCheck).to receive(:new).and_return(geo_health_check)
      end

      context 'when replication is enabled' do
        let(:geo_health_check) do
          instance_double(Gitlab::Geo::HealthCheck, perform_checks: '', db_replication_lag_seconds: 1000)
        end

        it 'returns the set replication lag' do
          expect(status.db_replication_lag_seconds).to eq(1000)
        end
      end

      context 'when replication is disabled' do
        let(:geo_health_check) do
          instance_double(Gitlab::Geo::HealthCheck, perform_checks: '', db_replication_lag_seconds: nil)
        end

        before do
          allow(Gitlab::Geo::HealthCheck).to receive(:new).and_return(geo_health_check)
        end

        it 'returns nil' do
          expect(status.db_replication_lag_seconds).to be_nil
        end
      end
    end

    it "doesn't attempt to set replication lag if primary" do
      stub_current_geo_node(primary)

      expect(status.db_replication_lag_seconds).to be_nil
    end
  end

  describe '#replication_slots_used_count' do
    it 'returns the right number of used replication slots' do
      stub_current_geo_node(primary)
      allow(primary).to receive(:replication_slots_used_count).and_return(1)

      expect(status.replication_slots_used_count).to eq(1)
    end
  end

  describe '#replication_slots_used_in_percentage' do
    it 'returns 0 when no replication slots are available' do
      expect(status.replication_slots_used_in_percentage).to eq(0)
    end

    it 'returns 0 when replication slot count is unknown' do
      status.replication_slots_count = nil

      expect(status.replication_slots_used_in_percentage).to eq(0)
    end

    it 'returns the right percentage' do
      stub_current_geo_node(primary)
      status.replication_slots_count = 2
      status.replication_slots_used_count = 1

      expect(status.replication_slots_used_in_percentage).to be_within(0.0001).of(50)
    end
  end

  describe '#replication_slots_max_retained_wal_bytes' do
    it 'returns the number of bytes replication slots are using' do
      stub_current_geo_node(primary)
      allow(primary).to receive(:replication_slots_max_retained_wal_bytes).and_return(2.megabytes)

      expect(status.replication_slots_max_retained_wal_bytes).to eq(2.megabytes)
    end

    it 'handles large values' do
      stub_current_geo_node(primary)
      allow(primary).to receive(:replication_slots_max_retained_wal_bytes).and_return(900.gigabytes)

      expect(status.replication_slots_max_retained_wal_bytes).to eq(900.gigabytes)
    end
  end

  describe '#last_event_id and #last_event_date' do
    it 'returns nil when no events are available' do
      expect(status.last_event_id).to be_nil
      expect(status.last_event_date).to be_nil
    end

    it 'returns the latest event' do
      created_at = Time.zone.today
      event = create(:geo_event_log, created_at: created_at)

      expect(status.last_event_id).to eq(event.id)
      expect(status.last_event_date).to eq(created_at)
    end
  end

  describe '#cursor_last_event_id and #cursor_last_event_date' do
    it 'returns nil when no events are available' do
      expect(status.cursor_last_event_id).to be_nil
      expect(status.cursor_last_event_date).to be_nil
    end

    it 'returns the latest event ID if secondary' do
      allow(Gitlab::Geo).to receive(:secondary?).and_return(true)
      event = create(:geo_event_log_state)

      expect(status.cursor_last_event_id).to eq(event.event_id)
    end

    it 'returns the latest event ID if org_migration_target' do
      stub_feature_flags(org_migration_target_cell: true)
      allow(Gitlab::Geo).to receive(:secondary?).and_return(false)
      event = create(:geo_event_log_state)

      expect(status.cursor_last_event_id).to eq(event.event_id)
    end

    it "doesn't attempt to retrieve cursor if primary" do
      stub_current_geo_node(primary)
      create(:geo_event_log_state)

      expect(status.cursor_last_event_date).to be_nil
      expect(status.cursor_last_event_id).to be_nil
    end
  end

  describe '#current_cursor_last_event_id' do
    context 'when on a primary node' do
      before do
        stub_current_geo_node(primary)
      end

      it 'returns nil' do
        expect(status.current_cursor_last_event_id).to be_nil
      end
    end

    context 'when on a secondary node' do
      it 'returns the minimum of gap_id and last_processed_id' do
        create(:geo_event_log_state, event_id: 10)
        allow(::Gitlab::Geo::EventGapTracking).to receive(:min_gap_id).and_return(15)

        expect(status.current_cursor_last_event_id).to eq(10)
      end
    end

    context 'when on an org migration target node' do
      before do
        stub_feature_flags(org_migration_target_cell: true)
        stub_current_geo_node(secondary)
      end

      it 'returns the minimum of gap_id and last_processed_id' do
        create(:geo_event_log_state, event_id: 20)
        allow(::Gitlab::Geo::EventGapTracking).to receive(:min_gap_id).and_return(25)

        expect(status.current_cursor_last_event_id).to eq(20)
      end
    end
  end

  describe '#load_secondary_or_org_migration_target_data' do
    subject(:status) { described_class.new }

    context 'when on a Geo primary node' do
      before do
        stub_feature_flags(org_migration_target_cell: false)
        stub_current_geo_node(primary)
      end

      it 'does not load org migration target data' do
        status.send(:load_secondary_or_org_migration_target_data)

        expect(status.cursor_last_event_id).to be_nil
      end
    end

    context 'when on a Geo secondary node' do
      before do
        stub_feature_flags(org_migration_target_cell: false)
        stub_current_geo_node(secondary)
        allow(status).to receive(:load_secondary_ssf_replicable_data)
        allow(status).to receive(:load_secondary_usage_data)
        allow(status).to receive(:current_cursor_last_event_id).and_return(nil)
      end

      it 'loads cursor last event metadata' do
        event_log = create(:geo_event_log)
        allow(status).to receive(:current_cursor_last_event_id).and_return(event_log.id)

        status.send(:load_secondary_or_org_migration_target_data)

        expect(status.cursor_last_event_id).to eq(event_log.id)
        expect(status.cursor_last_event_date).to be_within(0.001.seconds).of(event_log.created_at)
      end

      it 'loads database replication lag' do
        allow_next_instance_of(Gitlab::Geo::HealthCheck) do |health_check|
          allow(health_check).to receive(:db_replication_lag_seconds).and_return(5)
        end

        status.send(:load_secondary_or_org_migration_target_data)

        expect(status.db_replication_lag_seconds).to eq(5)
      end
    end

    context 'when on an org migration target node' do
      before do
        stub_feature_flags(org_migration_target_cell: true)
        allow(Gitlab::Geo).to receive(:secondary?).and_return(false)
        stub_current_geo_node(secondary)
        allow(status).to receive(:load_secondary_ssf_replicable_data)
        allow(status).to receive(:load_secondary_usage_data)
        allow(status).to receive(:current_cursor_last_event_id).and_return(nil)
      end

      it 'loads cursor last event metadata' do
        event_log = create(:geo_event_log)
        allow(status).to receive(:current_cursor_last_event_id).and_return(event_log.id)

        status.send(:load_secondary_or_org_migration_target_data)

        expect(status.cursor_last_event_id).to eq(event_log.id)
        expect(status.cursor_last_event_date).to be_within(0.001.seconds).of(event_log.created_at)
      end

      it 'does not load database replication lag' do
        allow_next_instance_of(Gitlab::Geo::HealthCheck) do |health_check|
          allow(health_check).to receive(:db_replication_lag_seconds).and_return(1000)
        end

        status.send(:load_secondary_or_org_migration_target_data)

        expect(status.db_replication_lag_seconds).to be_nil
      end
    end
  end

  describe '#version' do
    it { expect(status.version).to eq(Gitlab::VERSION) }
  end

  describe '#revision' do
    it { expect(status.revision).to eq(Gitlab.revision) }
  end

  describe '#[]' do
    it 'returns values for each attribute' do
      expect(status[:project_repositories_count]).to eq(0)
      expect(status[:projects_count]).to be_nil
    end

    it 'raises an error for invalid attributes' do
      expect { status[:testme] }.to raise_error(NoMethodError)
    end
  end

  shared_examples 'timestamp parameters' do |timestamp_column, date_column|
    it 'returns the value it was assigned via UNIX timestamp' do
      now = Time.current.beginning_of_day.utc
      status.update_attribute(timestamp_column, now.to_i)

      expect(status.public_send(date_column)).to eq(now)
      expect(status.public_send(timestamp_column)).to eq(now.to_i)
    end
  end

  describe '#last_successful_status_check_timestamp' do
    it_behaves_like 'timestamp parameters', :last_successful_status_check_timestamp, :last_successful_status_check_at
  end

  describe '#last_event_timestamp' do
    it_behaves_like 'timestamp parameters', :last_event_timestamp, :last_event_date
  end

  describe '#cursor_last_event_timestamp' do
    it_behaves_like 'timestamp parameters', :cursor_last_event_timestamp, :cursor_last_event_date
  end

  describe '#storage_shards' do
    it "returns the current node's shard config" do
      expect(status[:storage_shards].as_json).to eq(StorageShard.all.as_json)
    end
  end

  describe '#storage_shards_match?' do
    it 'returns false if no shard data is available for secondary' do
      stub_primary_node
      stub_current_geo_node(secondary)

      status = create(:geo_node_status, geo_node: secondary,
        storage_configuration_digest: 'bc11119c101846c20367fff34ce9fffa9b05aab8')

      expect(status.storage_shards_match?).to be false
    end

    it 'returns true even if no shard data is available for secondary' do
      stub_secondary_node
      stub_current_geo_node(primary)

      status = create(:geo_node_status, geo_node: primary,
        storage_configuration_digest: 'bc11119c101846c20367fff34ce9fffa9b05aab8')

      expect(status.storage_shards_match?).to be true
    end

    it 'returns false if the storage shards do not match' do
      stub_primary_node
      stub_current_geo_node(secondary)
      create(:geo_node_status, geo_node: primary,
        storage_configuration_digest: 'aea7849c10b886c202676ff34ce9fdf0940567b8')

      status = create(:geo_node_status, geo_node: secondary,
        storage_configuration_digest: 'bc11119c101846c20367fff34ce9fffa9b05aab8')

      expect(status.storage_shards_match?).to be false
    end
  end

  describe '#projects_count' do
    it 'returns nil on a primary site' do
      stub_current_geo_node(primary)

      expect(status.projects_count).to be_nil
    end

    it 'returns nil on a secondary site' do
      stub_current_geo_node(secondary)

      create(:geo_project_repository_registry, :synced, project: project_1)
      create(:geo_project_repository_registry, project: project_3)

      expect(status.projects_count).to be_nil
    end
  end

  describe '#repositories_count' do
    it 'counts the number of project repositories on a primary site' do
      stub_current_geo_node(primary)

      expect(status.repositories_count).to eq 4
    end

    it 'counts the number of project repository registries on a secondary site' do
      stub_current_geo_node(secondary)

      create(:geo_project_repository_registry, :synced, project: project_1)
      create(:geo_project_repository_registry, project: project_3)

      expect(status.repositories_count).to eq 2
    end
  end

  describe '#repositories_checked_count' do
    before do
      stub_application_setting(repository_checks_enabled: true)
    end

    context 'when current is a Geo primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'counts the number of repo checked projects' do
        project_1.update!(last_repository_check_at: 2.minutes.ago)
        project_2.update!(last_repository_check_at: 7.minutes.ago)

        expect(status.repositories_checked_count).to be_nil
      end
    end

    context 'when current is a Geo secondary' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'returns nil' do
        project_1.update!(last_repository_check_at: 2.minutes.ago)
        project_2.update!(last_repository_check_at: 7.minutes.ago)

        expect(status.repositories_checked_count).to be_nil
      end
    end
  end

  describe '#repositories_checked_failed_count' do
    before do
      stub_application_setting(repository_checks_enabled: true)
    end

    context 'when current is a Geo primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'counts the number of repo check failed projects' do
        project_1.update!(last_repository_check_at: 2.minutes.ago, last_repository_check_failed: true)
        project_2.update!(last_repository_check_at: 7.minutes.ago, last_repository_check_failed: false)

        expect(status.repositories_checked_failed_count).to be_nil
      end
    end

    context 'when current is a Geo secondary' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'returns nil' do
        project_1.update!(last_repository_check_at: 2.minutes.ago, last_repository_check_failed: true)
        project_2.update!(last_repository_check_at: 7.minutes.ago, last_repository_check_failed: false)

        expect(status.repositories_checked_failed_count).to be_nil
      end
    end
  end

  context 'for secondary usage data' do
    shared_examples_for 'a field from secondary_usage_data' do |field|
      describe '#load_secondary_usage_data' do
        it 'loads the latest data from Geo::SecondaryUsageData' do
          data = create(:geo_secondary_usage_data)

          expect(described_class.current_node_status.status[field]).to eq(data.payload[field])
        end

        it 'reports nil if there is no collected data in Geo::SecondaryUsageData' do
          expect(status.status[field]).to be_nil
        end
      end
    end

    described_class.usage_data_fields.each do |field|
      describe "##{field}" do
        it_behaves_like 'a field from secondary_usage_data', field
      end
    end
  end

  context 'for Replicator stats' do
    before_all do
      Project.delete_all
    end

    before do
      stub_geo_setting(registry_replication: { enabled: true })
      stub_container_registry_config(enabled: true)
      stub_feature_flags(geo_job_artifact_verification_summaries: false)

      stub_const('Gitlab::Geo::REPLICATOR_CLASSES', [replicator])
    end

    where(
      replicator: Gitlab::Geo::REPLICATOR_CLASSES
    )

    with_them do
      let(:registry_class) { replicator.registry_class }
      let(:replicable_name) { replicator.replicable_name_plural }
      let(:model_factory) { model_class_factory_name(registry_class) }
      let(:registry_factory) { registry_factory_name(registry_class) }

      context 'for replication' do
        context 'on the primary' do
          before do
            stub_current_geo_node(primary)
          end

          describe '#<replicable_name>_count' do
            let(:replicable_count_method) { "#{replicable_name}_count" }

            context 'when replication is enabled' do
              before do
                allow(replicator).to receive(:replication_enabled?).and_return(true)
              end

              context 'when there are replicables' do
                before do
                  create_list(model_factory, 2)
                end

                it 'returns the number of available replicables on primary' do
                  expect(status.send(replicable_count_method)).to eq(2)
                end
              end

              context 'when there are no replicables' do
                it 'returns 0' do
                  expect(status.send(replicable_count_method)).to eq(0)
                end
              end
            end

            context 'when replication is disabled' do
              before do
                allow(replicator).to receive(:replication_enabled?).and_return(false)
              end

              context 'and primary checksumming is enabled' do
                before do
                  allow(replicator).to receive(:verification_enabled?).and_return(true)
                end

                context 'when there are replicables' do
                  before do
                    create_list(model_factory, 2)
                  end

                  it 'returns the number of available replicables on primary' do
                    expect(status.send(replicable_count_method)).to eq(2)
                  end
                end

                context 'when there are no replicables' do
                  it 'returns 0' do
                    expect(status.send(replicable_count_method)).to eq(0)
                  end
                end
              end

              context 'and primary checksumming is disabled' do
                before do
                  allow(replicator).to receive(:verification_enabled?).and_return(false)

                  create_list(model_factory, 1)
                end

                it 'returns nil' do
                  expect(status.send(replicable_count_method)).to be_nil
                end
              end
            end
          end
        end

        context 'on the secondary' do
          let(:registry_count_method) { "#{replicable_name}_registry_count" }
          let(:failed_count_method) { "#{replicable_name}_failed_count" }
          let(:synced_count_method) { "#{replicable_name}_synced_count" }
          let(:synced_in_percentage_method) { "#{replicable_name}_synced_in_percentage" }
          let(:oldest_unsynced_time_method) { "#{replicable_name}_oldest_unsynced_time" }

          before do
            stub_current_geo_node(secondary)
          end

          describe '#<replicable_name>_(registry|synced|failed)_count' do
            context 'when there are registries' do
              before do
                create(registry_factory, :failed)
                create(registry_factory, :failed)
                create(registry_factory, :synced)
              end

              it 'returns the right counts', :aggregate_failures do
                expect(status.send(registry_count_method)).to eq(3)

                expect(status.send(failed_count_method)).to eq(2)
                expect(status.send(synced_count_method)).to eq(1)

                expect(status.send(synced_in_percentage_method)).to be_within(0.01).of(33.33)
              end

              it 'sets the oldest_unsynced_time' do
                expect(status.send(oldest_unsynced_time_method)).not_to be_nil
              end
            end

            context 'when there are no registries' do
              it 'returns 0', :aggregate_failures do
                expect(status.send(registry_count_method)).to eq(0)

                expect(status.send(failed_count_method)).to eq(0)
                expect(status.send(synced_count_method)).to eq(0)

                expect(status.send(synced_in_percentage_method)).to eq(0)
                expect(status.send(oldest_unsynced_time_method)).to eq(-1)
              end
            end
          end
        end
      end

      context 'for verification' do
        context 'on the primary' do
          let(:checksummed_count_method) { "#{replicable_name}_checksummed_count" }
          let(:checksum_failed_count_method) { "#{replicable_name}_checksum_failed_count" }

          before do
            stub_current_geo_node(primary)
          end

          context 'when verification is enabled' do
            before do
              allow(replicator).to receive(:verification_enabled?).and_return(true)
            end

            context 'when there are replicables' do
              before do
                create(model_factory, :verification_succeeded)
                create(model_factory, :verification_succeeded)
                create(model_factory, :verification_failed)
              end

              it 'returns the right checksum counts', :aggregate_failures do
                expect(status.send(checksummed_count_method)).to eq(2)
                expect(status.send(checksum_failed_count_method)).to eq(1)
              end
            end

            context 'when there are no replicables' do
              it 'returns 0', :aggregate_failures do
                expect(status.send(checksummed_count_method)).to eq(0)
                expect(status.send(checksum_failed_count_method)).to eq(0)
              end
            end
          end

          context 'when verification is disabled' do
            before do
              allow(replicator).to receive(:verification_enabled?).and_return(false)
            end

            it 'returns nil', :aggregate_failures do
              expect(status.send(checksummed_count_method)).to be_nil
              expect(status.send(checksum_failed_count_method)).to be_nil
            end
          end
        end

        context 'on the secondary' do
          let(:verified_count_method) { "#{replicable_name}_verified_count" }
          let(:verification_failed_count_method) { "#{replicable_name}_verification_failed_count" }
          let(:verified_in_percentage_method) { "#{replicable_name}_verified_in_percentage" }

          before do
            stub_current_geo_node(secondary)
          end

          context 'when verification is enabled' do
            before do
              allow(replicator).to receive(:verification_enabled?).and_return(true)
            end

            context 'when there are replicables' do
              before do
                create(registry_factory, :verification_succeeded)
                create(registry_factory, :verification_succeeded)
                create(registry_factory, :verification_failed)
              end

              it 'returns the right counts and percentage', :aggregate_failures do
                expect(status.send(verified_count_method)).to eq(2)
                expect(status.send(verification_failed_count_method)).to eq(1)
                expect(status.send(verified_in_percentage_method)).to be_within(0.01).of(66.67)
              end
            end

            context 'when there are no replicables' do
              it 'returns 0', :aggregate_failures do
                expect(status.send(verified_count_method)).to eq(0)
                expect(status.send(verification_failed_count_method)).to eq(0)
                expect(status.send(verified_in_percentage_method)).to eq(0)
              end
            end
          end

          context 'when verification is disabled' do
            before do
              allow(replicator).to receive(:verification_enabled?).and_return(false)
            end

            it 'returns nil', :aggregate_failures do
              expect(status.send(verified_count_method)).to be_nil
              expect(status.send(verification_failed_count_method)).to be_nil
              expect(status.send(verified_in_percentage_method)).to eq(0)
            end
          end
        end
      end
    end

    context 'for container repository verification' do
      let(:replicator) { Geo::ContainerRepositoryReplicator }

      before do
        stub_container_registry_config(enabled: false)
      end

      context 'on primary site' do
        before do
          stub_current_geo_node(primary)
        end

        it 'returns nil for container repository verification metrics' do
          create_list(:container_repository, 2)

          expect(status.container_repositories_count).to be_nil
          expect(status.container_repositories_checksum_total_count).to be_nil
          expect(status.container_repositories_checksummed_count).to be_nil
          expect(status.container_repositories_checksum_failed_count).to be_nil
          expect(status.container_repositories_verification_failed_count).to be_nil
        end
      end

      context 'on secondary site' do
        before do
          stub_current_geo_node(secondary)
        end

        it 'returns nil for container repository metrics' do
          container_repos = create_list(:container_repository, 2)
          create(:geo_container_repository_registry, :synced,
            container_repository: container_repos.first)

          expect(status.container_repositories_verified_count).to be_nil
          expect(status.container_repositories_verification_failed_count).to be_nil
          expect(status.container_repositories_registry_count).to be_nil
        end
      end
    end
  end

  describe '#load_data_from_current_node' do
    context 'on the primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'does not call JobArtifactRegistryFinder#registry_count' do
        expect_any_instance_of(Geo::JobArtifactRegistryFinder) do |instance|
          expect(instance).not_to receive(:registry_count)
        end

        status
      end
    end

    context 'on the secondary' do
      it 'returns data from the deprecated field if it is not defined in the status field' do
        status.write_attribute(:projects_count, 10)
        status.status = {}

        expect(status.projects_count).to eq 10
      end

      it 'sets data in the new status field' do
        status.projects_count = 10

        expect(status.projects_count).to eq 10
      end
    end

    context 'when status counters are converted into integers' do
      it 'returns integer value' do
        status.status = { "projects_count" => "10" }

        expect(status.projects_count).to eq 10
      end
    end

    context 'when status booleans are converted into booleans' do
      it 'returns boolean value' do
        status.status = { "container_repositories_replication_enabled" => "true" }

        expect(status.container_repositories_replication_enabled).to be true
      end
    end

    context 'when collecting the primary count metric', :use_clean_rails_memory_store_caching do
      let(:replicator) { Geo::JobArtifactReplicator }
      let(:status) { described_class.new }

      before do
        allow(replicator).to receive(:primary_total_count).and_return(7)
      end

      context 'when running inside the scheduled Sidekiq worker' do
        before do
          allow(Gitlab::Runtime).to receive(:sidekiq?).and_return(true)
        end

        it 'computes primary_total_count once within the cache window' do
          expect(status.send(:cached_primary_total_count, replicator)).to eq(7)
          expect(status.send(:cached_primary_total_count, replicator)).to eq(7)
          expect(replicator).to have_received(:primary_total_count).once
        end
      end

      context 'when called outside the scheduled Sidekiq worker (for example, a console)' do
        before do
          allow(Gitlab::Runtime).to receive(:sidekiq?).and_return(false)
        end

        it 'skips reading the cache and recomputes every call' do
          expect(status.send(:cached_primary_total_count, replicator)).to eq(7)
          expect(status.send(:cached_primary_total_count, replicator)).to eq(7)
          expect(replicator).to have_received(:primary_total_count).twice
        end

        it 'writes the fresh value back to the cache' do
          key = "geo:primary_total_count:#{replicator.replicable_name}"
          Rails.cache.write(key, 424_242, expires_in: described_class::PRIMARY_TOTAL_COUNT_CACHE_EXPIRY)

          status.send(:cached_primary_total_count, replicator)

          expect(Rails.cache.read(key)).to eq(7)
        end
      end
    end

    context 'when a primary metric query times out' do
      before do
        stub_current_geo_node(primary)
        stub_primary_site
        allow(Gitlab::Geo).to receive(:verification_enabled_replicator_classes)
                                .and_return([Geo::JobArtifactReplicator])
        allow(Geo::JobArtifactReplicator).to receive(:primary_total_count)
            .and_raise(ActiveRecord::QueryCanceled.new("ERROR: canceling statement due to statement timeout"))
        allow(Geo::JobArtifactReplicator).to receive(:checksummed_count)
            .and_return(42)
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'fails gracefully and continues collecting other metrics', :aggregate_failures do
        status # this triggers load_data_from_current_node

        # Failed counts are nil but following metrics are returned normally
        expect(status.job_artifacts_count).to be_nil
        expect(status.job_artifacts_checksummed_count).to eq(42)
      end

      it 'calls ErrorTracking for query cancellation errors' do
        status # this triggers load_data_from_current_node

        expect(Gitlab::ErrorTracking).to have_received(:track_exception)
            .with(instance_of(ActiveRecord::QueryCanceled), extra: { metric: 'job_artifacts_count' }).once
      end
    end

    context 'when a secondary metric query times out' do
      before do
        stub_current_geo_node(secondary)
        stub_secondary_site
        allow(Gitlab::Geo).to receive(:replication_enabled_replicator_classes)
                                .and_return([Geo::JobArtifactReplicator])
        allow(Geo::JobArtifactReplicator).to receive(:registry_count)
            .and_raise(ActiveRecord::QueryCanceled.new("ERROR: canceling statement due to statement timeout"))
        allow(Geo::JobArtifactReplicator).to receive(:synced_count)
            .and_return(42)
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'fails gracefully and continues collecting other metrics', :aggregate_failures do
        status # this triggers load_data_from_current_node

        # Failed counts are nil but following metrics are returned normally
        expect(status.job_artifacts_count).to be_nil
        expect(status.job_artifacts_synced_count).to eq(42)
      end

      it 'calls ErrorTracking for query cancellation errors' do
        status # this triggers load_data_from_current_node

        expect(Gitlab::ErrorTracking).to have_received(:track_exception)
            .with(instance_of(ActiveRecord::QueryCanceled), extra: { metric: 'job_artifacts_count' }).once
      end
    end

    context 'when approaching job TTL when called from metrics worker' do
      let(:started_at) { 55.minutes.ago } # With 1 hour TTL and 10 min buffer
      let(:timeout) { 1.hour }

      before do
        stub_current_geo_node(primary)
        stub_primary_site
        allow(Gitlab::Geo).to receive(:verification_enabled_replicator_classes)
                                .and_return([Geo::JobArtifactReplicator])
        allow(Gitlab::ErrorTracking).to receive(:track_and_raise_exception).and_call_original
      end

      it 'raises error and stops collecting metrics', :aggregate_failures do
        status = primary.find_or_build_status
        status.started_at = started_at
        status.timeout = timeout

        expect { status.load_data_from_current_node }
          .to raise_error(Geo::Errors::StatusTimeoutError)
      end

      it 'continues collecting metrics when not from metrics worker' do
        status = primary.find_or_build_status
        status.started_at = nil
        status.timeout = nil

        expect { status.load_data_from_current_node }.not_to raise_error
      end

      it 'tracks the error before raising' do
        status = primary.find_or_build_status
        status.started_at = started_at
        status.timeout = timeout

        expect { status.load_data_from_current_node }
          .to raise_error(Geo::Errors::StatusTimeoutError)

        expect(Gitlab::ErrorTracking).to have_received(:track_and_raise_exception)
                                           .with(
                                             instance_of(Geo::Errors::StatusTimeoutError),
                                             extra: hash_including(
                                               time_elapsed: kind_of(Float),
                                               timeout: timeout,
                                               assumed_query_timeout: 10.minutes
                                             )
                                           )
      end
    end
  end
end
