# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:geo rake tasks', :geo, :silence_stdout, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  before do
    Rake.application.rake_require 'tasks/gitlab/geo'
    Rake.application.rake_require 'tasks/gitlab/geo/replication'
    Rake.application.rake_require 'tasks/gitlab/geo/dev'
    Rake.application.rake_require 'tasks/gitlab/helpers'
    # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
    # is not allowed within a transaction but all RSpec tests run inside of a transaction.
    stub_batch_counter_transaction_open_check
    stub_licensed_features(geo: true)
  end

  describe 'gitlab:geo:check_replication_verification_status' do
    let(:run_task) { run_rake_task('gitlab:geo:check_replication_verification_status') }
    let!(:current_node) { create(:geo_node) }
    let!(:geo_node_status) { build(:geo_node_status, :healthy, geo_node: current_node) }

    around do |example|
      example.run
    rescue SystemExit
    end

    before do
      allow(GeoNodeStatus).to receive(:current_node_status).and_return(geo_node_status)
      allow(Gitlab.config.geo.registry_replication).to receive(:enabled).and_return(true)

      allow(Gitlab::Geo::GeoNodeStatusCheck).to receive(:replication_verification_complete?)
                                                  .and_return(complete)
    end

    context 'when replication is up-to-date' do
      let(:complete) { true }

      it 'prints a success message' do
        expect { run_task }.to output(/SUCCESS - Replication is up-to-date/).to_stdout
      end
    end

    context 'when replication is not up-to-date' do
      let(:complete) { false }

      it 'prints an error message' do
        expect { run_task }.to output(/ERROR - Replication is not up-to-date/).to_stdout
      end

      it 'exits with a 1' do
        expect { run_task }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end

    context 'on a primary node' do
      let(:complete) { true }

      let!(:geo_primary_node) { create(:geo_node, :primary) }
      let!(:geo_node_status) { build(:geo_node_status, :healthy, geo_node: geo_primary_node) }

      before do
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(geo_node_status)
      end

      it 'shows an error that the command is only available on a secondary node' do
        expect do
          run_task
        rescue SystemExit
        end.to output(/only available on a secondary node/).to_stdout
      end
    end

    context 'on an org migration target' do
      before do
        stub_org_migration_target_cell(current_node)
      end

      context 'when replication is up-to-date' do
        let(:complete) { true }

        it 'prints a success message' do
          expect { run_task }.to output(/SUCCESS - Replication is up-to-date/).to_stdout
        end
      end
    end

    context 'when geo is not properly configured' do
      let(:complete) { true }

      before do
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(nil)
      end

      it 'aborts with a helpful message instead of raising NoMethodError' do
        expect { run_task }.to raise_error("Gitlab Geo is not configured for this site")
      end
    end
  end

  describe 'gitlab:geo:prevent_updates_to_primary_site' do
    let(:run_task) do
      run_rake_task('gitlab:geo:prevent_updates_to_primary_site')
    end

    context 'on a primary site' do
      before do
        stub_primary_node
      end

      it 'enables maintenance mode and drains non-Geo queues' do
        expect(Gitlab::Geo::GeoTasks).to receive(:enable_maintenance_mode)
        expect(Gitlab::Geo::GeoTasks).to receive(:drain_non_geo_queues)

        run_task
      end
    end

    context 'on a secondary site' do
      it 'aborts' do
        stub_secondary_node

        expect { run_task }.to abort_execution.with_message(/This command is only available on a primary node/)
      end
    end

    context 'on a site without Geo enabled' do
      it 'aborts' do
        expect { run_task }.to abort_execution.with_message(/This command is only available on a primary node/)
      end
    end
  end

  describe 'gitlab:geo:wait_until_replicated_and_verified' do
    let(:run_task) do
      run_rake_task('gitlab:geo:wait_until_replicated_and_verified')
    end

    context 'on a primary site' do
      it 'aborts' do
        stub_primary_node

        expect { run_task }.to abort_execution.with_message(/This command is only available on a secondary node/)
      end
    end

    context 'on a secondary site' do
      before do
        stub_secondary_node
      end

      it 'waits until everything is replicated and verified' do
        expect(Gitlab::Geo::GeoTasks).to receive(:wait_until_replicated_and_verified)

        run_task
      end
    end

    context 'on an org migration target' do
      before do
        stub_org_migration_target_cell
      end

      it 'waits until everything is replicated and verified' do
        expect(Gitlab::Geo::GeoTasks).to receive(:wait_until_replicated_and_verified)

        run_task
      end
    end

    context 'on a site without Geo enabled' do
      it 'aborts' do
        expect { run_task }.to abort_execution.with_message(/This command is only available on a secondary node/)
      end
    end
  end

  describe 'gitlab:geo:set_primary_node' do
    before do
      stub_config_setting(url: 'https://example.com:1234/relative_part')
      stub_geo_setting(node_name: 'Region 1 node')
    end

    it 'creates a GeoNode' do
      expect(GeoNode.count).to eq(0)

      run_rake_task('gitlab:geo:set_primary_node')

      expect(GeoNode.count).to eq(1)

      node = GeoNode.first

      expect(node.name).to eq('Region 1 node')
      expect(node.uri.scheme).to eq('https')
      expect(node.url).to eq('https://example.com:1234/relative_part/')
      expect(node.primary).to be_truthy
    end
  end

  describe 'gitlab:geo:set_secondary_as_primary', :use_clean_rails_memory_store_caching do
    let!(:current_node) { create(:geo_node) }
    let!(:primary_node) { create(:geo_node, :primary) }
    let(:execute) do
      Gitlab::SidekiqSharding::Validator.allow_unrouted_sidekiq_calls do
        run_rake_task('gitlab:geo:set_secondary_as_primary')
      end
    end

    before do
      stub_current_geo_node(current_node)

      allow(GeoNode).to receive(:current_node).and_return(current_node)
    end

    it 'removes primary and sets secondary as primary' do
      # Pre-warming the cache. See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/22021
      Gitlab::Geo.primary_node

      execute

      expect(current_node.primary?).to be_truthy
      expect(GeoNode.count).to eq(1)
    end

    context 'with the ENABLE_SILENT_MODE env var set' do
      it 'enables silent mode' do
        stub_env('ENABLE_SILENT_MODE' => true)

        expect { execute }
          .to change { Gitlab::CurrentSettings.silent_mode_enabled? }
                .from(false)
                .to(true)
      end
    end

    context 'when the ENABLE_SILENT_MODE env var is unset' do
      it 'does not enable silent mode' do
        stub_env('ENABLE_SILENT_MODE' => nil)

        expect { execute }
          .not_to change { Gitlab::CurrentSettings.silent_mode_enabled? }
      end
    end
  end

  describe 'gitlab:geo:update_primary_node_url' do
    before do
      allow(GeoNode).to receive(:current_node_url).and_return('https://primary.geo.example.com')
      stub_current_geo_node(current_node)
    end

    context 'when the machine Geo node name is not explicitly configured' do
      let(:current_node) { create(:geo_node, :primary, url: 'https://secondary.geo.example.com', name: 'https://secondary.geo.example.com') }

      before do
        # As if Gitlab.config.geo.node_name is defaulting to external_url (this happens in an initializer)
        allow(GeoNode).to receive(:current_node_name).and_return('https://primary.geo.example.com')
      end

      it 'updates Geo primary node URL and name' do
        run_rake_task('gitlab:geo:update_primary_node_url')

        expect(current_node.reload.url).to eq 'https://primary.geo.example.com/'
        expect(current_node.name).to eq 'https://primary.geo.example.com'
      end
    end

    context 'when the machine Geo node name is explicitly configured' do
      context 'when the Geo node is a secondary' do
        let(:current_node) { create(:geo_node, :secondary) }

        it 'fails' do
          expect { run_rake_task('gitlab:geo:update_primary_node_url') }
            .to output(/This is not a primary node/).to_stdout.and raise_error(SystemExit)
        end
      end

      context 'when the Geo node is a primary' do
        let(:node_name) { 'Brazil DC' }
        let(:current_node) { create(:geo_node, :primary, url: 'https://secondary.geo.example.com', name: node_name) }

        before do
          allow(GeoNode).to receive(:current_node_name).and_return(node_name)
        end

        context 'when the update fails' do
          it 'fails' do
            current_node.repos_max_capacity = -1 # Update will fail on validation error
            allow(Gitlab::Geo).to receive(:primary_node).and_return(current_node)

            expect { run_rake_task('gitlab:geo:update_primary_node_url') }
              .to output(/Error saving Geo node/).to_stdout.and raise_error(SystemExit)
          end
        end

        context 'when the update succeeds' do
          it 'updates Geo primary node URL only' do
            run_rake_task('gitlab:geo:update_primary_node_url')

            expect(current_node.reload.url).to eq 'https://primary.geo.example.com/'
            expect(current_node.name).to eq node_name
          end
        end
      end
    end
  end

  describe 'gitlab:geo:status' do
    context 'when geo is not properly configured' do
      it 'returns misconfigured when not a primary nor a secondary site' do
        expect { run_rake_task('gitlab:geo:status') }.to raise_error("Gitlab Geo is not configured for this site")
      end
    end

    context 'without a valid license' do
      before do
        stub_licensed_features(geo: false)
      end

      it 'runs with an error' do
        expect { run_rake_task('gitlab:geo:status') }
          .to raise_error("GitLab Geo is not supported with this license. Please contact the sales team: https://about.gitlab.com/sales.")
      end
    end

    context 'with a valid license' do
      let!(:primary_node) { create(:geo_node, :primary) }
      let!(:secondary_node) { create(:geo_node, :secondary) }
      let!(:geo_event_log) { create(:geo_event_log) }
      let!(:geo_node_status) { build(:geo_node_status, :healthy, geo_node: secondary_node) }
      let(:self_service_framework_checks) do
        Gitlab::Geo.verification_enabled_replicator_classes.map { |k| /#{k.replicable_title_plural} verified:/ } +
          Gitlab::Geo.replication_enabled_replicator_classes.map { |k| /#{k.replicable_title_plural} replicated:/ }
      end

      before do
        stub_licensed_features(geo: true)
        stub_current_geo_node(secondary_node)

        allow(GeoNodeStatus).to receive(:current_node_status).and_return(geo_node_status)
        allow(Gitlab.config.geo.registry_replication).to receive(:enabled).and_return(true)
      end

      it 'runs with no error' do
        expect { run_rake_task('gitlab:geo:status') }.not_to raise_error
      end

      context 'with a healthy node' do
        before do
          geo_node_status.status_message = nil
        end

        it 'shows status as healthy' do
          expect { run_rake_task('gitlab:geo:status') }.to output(/Health Status: Healthy/).to_stdout
        end

        it 'does not show health status summary' do
          expect { run_rake_task('gitlab:geo:status') }.not_to output(/Health Status Summary/).to_stdout
        end

        it 'prints messages for all the checks' do
          checks = [
            /Name: /,
            /URL: /,
            /This Node's GitLab Version: /,
            /Geo Role: /,
            /Health Status: /,
            /Sync Settings: /,
            /Database replication lag: /,
            /Last event ID seen from primary: /,
            /Last status report was: /
          ] + self_service_framework_checks

          expect { run_rake_task('gitlab:geo:status') }.to output(
            satisfy { |out| checks.all? { |pattern| out.match?(pattern) } }
          ).to_stdout
        end

        context 'for database replication lag' do
          let(:health_check) { instance_double(Gitlab::Geo::HealthCheck) }

          before do
            allow(Gitlab::Geo::HealthCheck).to receive(:new).and_return(health_check)
          end

          it 'prints N/A when replication is not enabled' do
            allow(health_check).to receive_messages(
              replication_enabled?: false,
              db_replication_lag_seconds: nil
            )

            expect { run_rake_task('gitlab:geo:status') }.to output(%r{Database replication lag: N/A}).to_stdout
          end

          it 'prints the lag in seconds when replication is enabled' do
            allow(health_check).to receive_messages(
              replication_enabled?: true,
              db_replication_lag_seconds: 120
            )

            expect { run_rake_task('gitlab:geo:status') }.to output(%r{Database replication lag: 120 seconds}).to_stdout
          end

          it 'prints N/A when replication is enabled but lag is nil' do
            allow(health_check).to receive_messages(
              replication_enabled?: true,
              db_replication_lag_seconds: nil
            )
            expect { run_rake_task('gitlab:geo:status') }.to output(%r{Database replication lag: N/A}).to_stdout
          end
        end

        context 'on a Geo primary site' do
          before do
            stub_current_geo_node(primary_node)
          end

          it 'prints a message for the repositories checked' do
            expect { run_rake_task('gitlab:geo:status') }.to output(/Repositories Checked:/).to_stdout
          end
        end
      end

      context 'with an unhealthy node' do
        before do
          geo_node_status.status_message = 'Something went wrong'
        end

        it 'shows status as unhealthy' do
          expect { run_rake_task('gitlab:geo:status') }.to output(/Health Status: Unhealthy/).to_stdout
        end

        it 'shows health status summary' do
          expect do
            run_rake_task('gitlab:geo:status')
          end.to output(/Health Status Summary: Something went wrong/).to_stdout
        end
      end
    end

    context 'on a primary node' do
      let!(:geo_primary_node) { create(:geo_node, :primary) }
      let!(:geo_node_status) { build(:geo_node_status, :healthy, geo_node: geo_primary_node) }

      before do
        stub_current_geo_node(geo_primary_node)
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(geo_node_status)
      end

      it 'shows an error that the command is only available on a secondary node' do
        expect do
          run_rake_task('gitlab:geo:status')
        rescue SystemExit
        end.to output(/only available on a secondary node/).to_stdout
      end
    end

    context 'with an org migration target node' do
      let!(:primary_node) { create(:geo_node, :primary) }
      let!(:org_migration_target_node) { create(:geo_node) }
      let!(:geo_node_status) { build(:geo_node_status, :healthy, geo_node: org_migration_target_node) }

      before do
        stub_org_migration_target_cell(org_migration_target_node)
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(geo_node_status)
        allow(Gitlab.config.geo.registry_replication).to receive(:enabled).and_return(true)
      end

      it 'runs with no error' do
        expect { run_rake_task('gitlab:geo:status') }.not_to raise_error
      end

      it 'shows Org Migration Target Cell role' do
        expect { run_rake_task('gitlab:geo:status') }.to output(/Org Migration Target Cell/).to_stdout
      end
    end
  end

  describe 'gitlab:geo:reverify_container_repositories_since' do
    let(:service) { instance_double(Geo::ReverifyContainerRepositoriesService) }
    let(:response) { ServiceResponse.success(message: 'Marked 2 container repositories for reverification.') }
    let(:run_task) { run_rake_task('gitlab:geo:reverify_container_repositories_since', '10') }

    around do |example|
      example.run
    rescue SystemExit
    end

    before do
      stub_current_geo_node(create(:geo_node, :primary))
      allow(Geo::ReverifyContainerRepositoriesService).to receive(:new).and_return(service)
      allow(service).to receive(:execute).and_return(response)
    end

    it 'reverifies container repositories verified since the requested cutoff' do
      travel_to(Time.zone.parse('2026-06-10 12:00:00 UTC')) do
        expected_cutoff = 10.days.ago

        expect(Geo::ReverifyContainerRepositoriesService).to receive(:new)
          .with(verified_after: expected_cutoff)
          .and_return(service)

        expect { run_task }
          .to output(
            "Marked 2 container repositories for reverification. (verified since #{expected_cutoff.iso8601})\n"
          ).to_stdout
      end
    end

    context 'with DRY_RUN=true' do
      let(:response) do
        ServiceResponse.success(message: 'DRY RUN: 42 container repositories would be marked for reverification.')
      end

      before do
        stub_env('DRY_RUN', 'true')
        allow(service).to receive(:dry_run).and_return(response)
      end

      it 'reports the count without updating anything' do
        expect(service).not_to receive(:execute)

        expect { run_task }
          .to output(/DRY RUN: 42 container repositories would be marked for reverification/)
          .to_stdout
      end
    end

    it 'defaults to seven days' do
      travel_to(Time.zone.parse('2026-06-10 12:00:00 UTC')) do
        expect(Geo::ReverifyContainerRepositoriesService).to receive(:new)
          .with(verified_after: 7.days.ago)
          .and_return(service)

        run_rake_task('gitlab:geo:reverify_container_repositories_since')
      end
    end

    it 'rejects a non-positive days argument' do
      expect { run_rake_task('gitlab:geo:reverify_container_repositories_since', '0') }
        .to output(/Days must be a positive integer/).to_stderr
        .and raise_error(SystemExit)
    end

    it 'rejects a non-numeric days argument' do
      expect { run_rake_task('gitlab:geo:reverify_container_repositories_since', 'abc') }
        .to output(/Days must be a positive integer/).to_stderr
        .and raise_error(SystemExit)
    end

    context 'without a valid license' do
      before do
        stub_licensed_features(geo: false)
      end

      it 'aborts with the license error' do
        expect { run_task }
          .to output(/GitLab Geo is not supported with this license/).to_stderr
          .and raise_error(SystemExit)
      end
    end

    it 'is only available on a primary node' do
      stub_current_geo_node(create(:geo_node, :secondary))

      expect { run_task }
        .to output(/This command is only available on a primary node/).to_stderr
        .and raise_error(SystemExit)
    end

    context 'when the service fails' do
      let(:response) { ServiceResponse.error(message: 'reverification failed') }

      it 'aborts with the service error' do
        expect { run_task }.to output(/reverification failed/).to_stderr.and raise_error(SystemExit)
      end
    end
  end

  describe 'gitlab:geo:site:role' do
    context 'when in a primary site' do
      it 'returns primary' do
        create(:geo_node, :primary, name: 'primary')
        allow(GeoNode).to receive(:current_node_name).and_return('primary')

        expect { run_rake_task('gitlab:geo:site:role') }.to output(/primary/).to_stdout
      end
    end

    context 'when in a secondary site' do
      it 'returns secondary' do
        create(:geo_node, :secondary, name: 'secondary')
        allow(GeoNode).to receive(:current_node_name).and_return('secondary')

        expect { run_rake_task('gitlab:geo:site:role') }.to output(/secondary/).to_stdout
      end
    end

    context 'when on an org migration target' do
      it 'returns org migration target cell' do
        stub_org_migration_target_cell

        expect { run_rake_task('gitlab:geo:site:role') }.to output(/org migration target cell/).to_stdout
      end
    end

    it 'returns misconfigured when not a primary nor a secondary site' do
      expect { run_rake_task('gitlab:geo:site:role') }.to output(/misconfigured/).to_stdout & raise_error(SystemExit)
    end
  end
end
