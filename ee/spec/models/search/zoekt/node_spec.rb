# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::Node, feature_category: :global_search do
  let_it_be_with_reload(:node) do
    create(:zoekt_node, index_base_url: 'http://example.com:1234/', search_base_url: 'http://example.com:4567/')
  end

  let_it_be(:indexed_namespace1) { create(:namespace) }
  let_it_be(:indexed_namespace2) { create(:namespace) }
  let_it_be(:unindexed_namespace) { create(:namespace) }
  let_it_be(:enabled_namespace1) { create(:zoekt_enabled_namespace, namespace: indexed_namespace1) }
  let_it_be(:zoekt_index) { create(:zoekt_index, :ready, node: node, zoekt_enabled_namespace: enabled_namespace1) }

  before do
    enabled_namespace2 = create(:zoekt_enabled_namespace, namespace: indexed_namespace2)
    create(:zoekt_index, :ready, node: node, zoekt_enabled_namespace: enabled_namespace2)
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:index_base_url) }
    it { is_expected.to validate_presence_of(:search_base_url) }
    it { is_expected.to validate_presence_of(:uuid) }
    it { is_expected.to validate_presence_of(:last_seen_at) }
    it { is_expected.to validate_presence_of(:indexed_bytes) }
    it { is_expected.to validate_presence_of(:used_bytes) }
    it { is_expected.to validate_presence_of(:total_bytes) }
    it { is_expected.to validate_presence_of(:usable_storage_bytes) }
    it { is_expected.to validate_presence_of(:schema_version) }
    it { is_expected.to validate_uniqueness_of(:uuid).case_insensitive }

    describe 'node URLs' do
      it 'allows creation of another node with the same URLs' do
        node2 = create(:zoekt_node, index_base_url: node.index_base_url, search_base_url: node.search_base_url)

        expect(node2.save).to be(true)
      end
    end

    describe 'metadata JSON schema validation' do
      it 'allows null values in version field' do
        node = build(:zoekt_node)
        node.metadata['version'] = nil

        expect(node).to be_valid
      end
    end

    describe 'valid_services' do
      using RSpec::Parameterized::TableSyntax

      where(:services, :is_valid) do
        []        | false
        nil       | false
        [:foo]    | false
        [0, :foo] | false
        [0, 10]   | false
        [0]       | true
      end

      with_them do
        it 'validates services array' do
          node = build(:zoekt_node, services: services)

          expect(node.valid?).to eq(is_valid)
        end
      end
    end
  end

  describe 'relations' do
    it { is_expected.to have_many(:indices).inverse_of(:node) }
    it { is_expected.to have_many(:tasks).inverse_of(:node) }
    it { is_expected.to have_many(:enabled_namespaces).through(:indices) }
    it { is_expected.to have_many(:zoekt_repositories).through(:indices) }
  end

  describe 'scopes' do
    describe '.lost', :freeze_time do
      let_it_be(:offline_node) { create(:zoekt_node, last_seen_at: 10.minutes.ago) }
      let_it_be(:lost_node) { create(:zoekt_node, :lost) }

      context 'when there is lost node threshold' do
        before do
          allow(::Search::Zoekt::Settings).to receive(:lost_node_threshold).and_return(30.minutes)
        end

        it 'returns all the lost nodes' do
          expect(described_class.lost).to contain_exactly(lost_node)
        end
      end

      context 'when there is no node threshold' do
        before do
          allow(::Search::Zoekt::Settings).to receive(:lost_node_threshold).and_return(nil)
        end

        it 'returns all the lost nodes' do
          expect(described_class.lost).to be_empty
        end
      end
    end

    describe '.with_pending_indices' do
      let_it_be(:node_with_pending_indices) { create(:zoekt_node) }
      let_it_be(:node_without_pending_indices) { create(:zoekt_node) }
      let_it_be(:node_with_ready_indices) { create(:zoekt_node) }

      before do
        create(:zoekt_index, state: :pending, node: node_with_pending_indices)
        create(:zoekt_index, state: :ready, node: node_with_ready_indices)
      end

      it 'returns only nodes that have pending indices' do
        expect(described_class.with_pending_indices).to contain_exactly(node_with_pending_indices)
      end

      it 'does not include nodes without pending indices' do
        expect(described_class.with_pending_indices).not_to include(node_without_pending_indices)
        expect(described_class.with_pending_indices).not_to include(node_with_ready_indices)
      end
    end

    describe '.online', :freeze_time do
      let_it_be(:online_node) { create(:zoekt_node) }
      let_it_be(:offline_node) { create(:zoekt_node, :offline) }

      it 'returns nodes considered to be online based on last_seen_at' do
        expect(described_class.online).to contain_exactly(node, online_node)
      end

      it 'is a pure liveness scope and does not consult ProcessHealth' do
        expect(::Search::Zoekt::ProcessHealth).not_to receive(:active?)

        described_class.online.to_a
      end

      context 'with nodes that have stale or nil webserver_last_seen_at' do
        let_it_be(:stale_webserver_node) { create(:zoekt_node, webserver_last_seen_at: 2.days.ago) }
        let_it_be(:nil_webserver_node) { create(:zoekt_node, webserver_last_seen_at: nil) }

        it 'ignores webserver_last_seen_at (that is .searchable\'s concern)' do
          expect(described_class.online).to include(stale_webserver_node, nil_webserver_node)
        end
      end
    end

    describe '.searchable', :freeze_time do
      let_it_be(:searchable_node) { create(:zoekt_node) }
      let_it_be(:non_searchable_node) { create(:zoekt_node, :offline) }

      it 'returns nodes considered to be searchable' do
        expect(described_class.searchable).to include searchable_node
        expect(described_class.searchable).not_to include non_searchable_node
      end

      context 'with process health filtering' do
        let_it_be_with_reload(:healthy_node) { create(:zoekt_node, :for_search, :healthy_process) }
        let_it_be(:unhealthy_node) { create(:zoekt_node, :for_search, :unhealthy_process) }

        context 'when process_health is active' do
          before do
            allow(::Search::Zoekt::ProcessHealth).to receive(:active?).and_return(true)
          end

          context 'when a subset of online nodes is unhealthy' do
            it 'excludes only the unhealthy nodes', :aggregate_failures do
              result = described_class.searchable

              expect(result).to include(healthy_node)
              expect(result).not_to include(unhealthy_node)
            end
          end

          context 'when all online nodes are unhealthy' do
            before do
              # Flip the healthy node to unhealthy by swapping its process_health
              # to match what the :unhealthy_process trait.
              healthy_node.update!(
                metadata: healthy_node.metadata.merge('process_health' => unhealthy_node.metadata['process_health'])
              )
            end

            it 'falls back to all online nodes to avoid cascade failure' do
              result = described_class.searchable

              expect(result).to include(healthy_node, unhealthy_node)
            end

            it 'logs a warning so operators can observe the degraded state' do
              logger = instance_double(::Search::Zoekt::Logger)
              allow(::Search::Zoekt::Logger).to receive(:build).and_return(logger)
              expect(logger).to receive(:warn).with(
                hash_including(
                  message: a_string_matching(/cascade-failure fallback/),
                  online_node_count: a_value > 0,
                  online_node_ids: include(healthy_node.id, unhealthy_node.id)
                )
              )

              described_class.searchable
            end
          end
        end

        context 'when process_health is not active' do
          before do
            allow(::Search::Zoekt::ProcessHealth).to receive(:active?).and_return(false)
          end

          it 'returns the .online relation unchanged' do
            result = described_class.searchable

            expect(result).to include(healthy_node, unhealthy_node)
          end
        end
      end
    end

    describe '.by_name' do
      let_it_be(:node1) { create(:zoekt_node, metadata: { name: 'node1' }) }
      let_it_be(:node2) { create(:zoekt_node, metadata: { name: 'node2' }) }
      let_it_be(:node3) { create(:zoekt_node, metadata: { name: 'node3' }) }

      it 'returns nodes filtered by name' do
        expect(described_class.by_name('node1')).to contain_exactly(node1)
        expect(described_class.by_name('node1', 'node2')).to contain_exactly(node1, node2)
        expect(described_class.by_name('non_existent')).to be_empty
      end
    end

    describe '.searchable_for_project' do
      let_it_be(:project) { create(:project, namespace: indexed_namespace1) }
      let_it_be(:zoekt_index) { create(:zoekt_index) }

      context 'when zoekt_repository for the given project does not exists' do
        it 'is empty' do
          expect(described_class.searchable_for_project(project)).to be_empty
        end
      end

      context 'when zoekt_repository for the given project exists' do
        let_it_be_with_reload(:zoekt_repository) do
          create(:zoekt_repository, project: project, zoekt_index: zoekt_index)
        end

        context 'when there is no ready repository' do
          it 'is empty' do
            expect(described_class.searchable_for_project(project)).to be_empty
          end
        end

        context 'when there is a ready repository' do
          before do
            zoekt_repository.ready!
          end

          it 'returns the nodes' do
            expect(described_class.searchable_for_project(project)).not_to be_empty
          end

          context 'when there is no online nodes' do
            before do
              described_class.update_all(last_seen_at: described_class::ONLINE_DURATION_THRESHOLD.ago - 1.hour)
            end

            it 'is empty' do
              expect(described_class.searchable_for_project(project)).to be_empty
            end
          end
        end
      end
    end

    describe '.with_reserved_bytes' do
      let_it_be(:node1) { create(:zoekt_node) }
      let_it_be(:node2) { create(:zoekt_node) }
      let_it_be(:node3) { create(:zoekt_node) }
      let_it_be(:index1) { create(:zoekt_index, node: node1, reserved_storage_bytes: 2000) }
      let_it_be(:index2) { create(:zoekt_index, node: node2, reserved_storage_bytes: 500) }

      subject(:with_reserved_bytes) { described_class.where(id: [node1, node2, node3]).with_reserved_bytes }

      it 'returns sum of reserved bytes or nil for each node' do
        expect(with_reserved_bytes.pluck(:reserved_storage_bytes_total)).to match_array([2000, 500, nil])
      end
    end

    describe '.negative_unclaimed_storage_bytes' do
      let_it_be_with_reload(:node_with_negative_storage) { create(:zoekt_node) }
      let_it_be_with_reload(:node_with_positive_storage) { create(:zoekt_node) }

      before do
        node_with_negative_storage.update!(total_bytes: 1000, used_bytes: 0, indexed_bytes: 0)
        node_with_positive_storage.update!(total_bytes: 2000, used_bytes: 0, indexed_bytes: 0)

        node_with_negative_storage.update!(usable_storage_bytes: 1000)
        node_with_positive_storage.update!(usable_storage_bytes: 2000)

        create(:zoekt_index, node: node_with_negative_storage, reserved_storage_bytes: 2000)
        create(:zoekt_index, node: node_with_positive_storage, reserved_storage_bytes: 500)
      end

      it 'includes only nodes with negative unclaimed storage' do
        expect(described_class.negative_unclaimed_storage_bytes.to_a).to include(node_with_negative_storage)
        expect(described_class.negative_unclaimed_storage_bytes.to_a).not_to include(node_with_positive_storage)
      end
    end

    describe '.with_positive_unclaimed_storage_bytes' do
      let_it_be_with_reload(:node_with_positive_storage) { create(:zoekt_node, :enough_free_space) }
      let_it_be(:node_with_zero_storage) { create(:zoekt_node, total_bytes: 1000, used_bytes: 1000) }
      let_it_be_with_reload(:node_with_negative_storage) { create(:zoekt_node, :enough_free_space) }

      # Scenario with positive unclaimed storage
      let_it_be(:index1) do
        create(:zoekt_index,
          node: node_with_positive_storage,
          reserved_storage_bytes: node_with_positive_storage.total_bytes / 3
        )
      end

      # Scenario with negative unclaimed storage
      let_it_be(:index2) do
        create(:zoekt_index,
          node: node_with_negative_storage,
          reserved_storage_bytes: node_with_negative_storage.total_bytes + 10
        )
      end

      it 'returns only nodes with non-negative unclaimed storage bytes' do
        positive_nodes = described_class.with_positive_unclaimed_storage_bytes

        expect(positive_nodes).to include(node_with_positive_storage)
        expect(positive_nodes).not_to include(node_with_zero_storage)
        expect(positive_nodes).not_to include(node_with_negative_storage)
      end

      it 'calculates unclaimed_storage_bytes correctly using SQL formula' do
        result = described_class.with_positive_unclaimed_storage_bytes

        expect(result).to match_array([node_with_positive_storage])
        expect(result[0]).to have_attribute('unclaimed_storage_bytes')
        expect(result[0]['unclaimed_storage_bytes']).to be > 0
        expect(result[0]['unclaimed_storage_bytes']).to eq(node_with_positive_storage.unclaimed_storage_bytes)
      end

      it 'groups results by node id to handle multiple indices' do
        # Create multiple indices for the same node
        create(:zoekt_index,
          node: node_with_positive_storage,
          reserved_storage_bytes: node_with_positive_storage.total_bytes / 4
        )

        results = described_class.with_positive_unclaimed_storage_bytes

        expect(results).to include(node_with_positive_storage)
      end

      context 'when no indices exist' do
        let_it_be(:node_without_indices) { create(:zoekt_node, :enough_free_space) }

        it 'includes nodes without indices if they have positive unclaimed storage' do
          results = described_class.with_positive_unclaimed_storage_bytes

          expect(results).to include(node_without_indices)
        end
      end
    end

    describe '.order_by_unclaimed_space_desc' do
      let_it_be(:node2) { create(:zoekt_node, :not_enough_free_space) }
      let_it_be(:node3) { create(:zoekt_node, :enough_free_space) }
      let_it_be(:node4) { create(:zoekt_node, :enough_free_space) }

      let_it_be(:index1) do
        create(:zoekt_index,
          node: node3,
          reserved_storage_bytes: 100_000
        )
      end

      it 'returns nodes with positive unclaimed storage_bytes in descending order' do
        expect(described_class.order_by_unclaimed_space_desc.to_a).to eq([node4, node3, node2])
      end
    end

    describe '.with_service' do
      let_it_be(:node1) { create(:zoekt_node, services: [described_class::SERVICES[:zoekt]]) }

      it "returns nodes which contain the service in the list of services" do
        expect(described_class.with_service(:zoekt).to_a).to match_array([node, node1])
      end
    end

    describe '.available_for_search_indexing' do
      it 'chains for_search, online, and order_by_unclaimed_space_desc scopes' do
        expect(described_class).to receive_message_chain(:for_search, :online, :order_by_unclaimed_space_desc)

        described_class.available_for_search_indexing
      end
    end
  end

  describe '.find_or_initialize_by_task_request', :freeze_time do
    let(:base_params) do
      {
        'uuid' => '3869fe21-36d1-4612-9676-0b783ef2dcd7',
        'node.name' => 'm1.local',
        'node.url' => 'http://localhost:6080',
        'disk.all' => 994662584320,
        'disk.free' => 461988872192,
        'disk.used' => 532673712128,
        'node.task_count' => 5,
        'node.concurrency' => 10
      }
    end

    subject(:tasked_node) { described_class.find_or_initialize_by_task_request(params) }

    shared_examples 'node with attributes from params' do
      it 'sets correct attributes' do
        expect(tasked_node.index_base_url).to eq(params['node.url'])
        expect(tasked_node.search_base_url).to eq(params['node.url'])
        expect(tasked_node.uuid).to eq(params['uuid'])
        expect(tasked_node.last_seen_at).to eq(Time.zone.now)
        expect(tasked_node.used_bytes).to eq(params['disk.used'])
        expect(tasked_node.total_bytes).to eq(params['disk.all'])
        expect(tasked_node.indexed_bytes).to eq(0)
        expect(tasked_node.schema_version).to eq(0)
        expect(tasked_node.services).to match_array([described_class::SERVICES[:zoekt]])
        expect(tasked_node.metadata['name']).to eq(params['node.name'])
        expect(tasked_node.metadata['task_count']).to eq(params['node.task_count'])
        expect(tasked_node.metadata['concurrency']).to eq(params['node.concurrency'])
        expect(tasked_node.metadata['version']).to be_nil
      end
    end

    context 'when node does not exist for given UUID' do
      let(:params) { base_params }

      it 'returns a new record' do
        expect(tasked_node).not_to be_persisted
      end

      it_behaves_like 'node with attributes from params'
    end

    context 'when node already exists for given UUID' do
      let(:params) { base_params.merge('uuid' => node.uuid) }

      it 'returns existing node' do
        expect(tasked_node).to be_persisted
      end

      it_behaves_like 'node with attributes from params'
    end

    context 'when node.search_url is set' do
      let(:params) { base_params.merge('node.search_url' => 'http://localhost:6090') }

      it 'sets search_base_url from params' do
        expect(tasked_node.search_base_url).to eq(params['node.search_url'])
      end
    end

    context 'when disk.indexed is present' do
      let(:params) { base_params.merge('disk.indexed' => 2416879) }

      it 'sets indexed_bytes to the disk.indexed from params' do
        expect(tasked_node.indexed_bytes).to eq(params['disk.indexed'])
      end
    end

    context 'when node.version is present' do
      let(:params) { base_params.merge('node.version' => '1.2.3') }

      it 'sets version in metadata' do
        expect(tasked_node.metadata['version']).to eq('1.2.3')
      end
    end

    context 'when node.schema_version is present' do
      let(:params) { base_params.merge('node.schema_version' => 2525) }

      it 'sets schema_version' do
        expect(tasked_node.schema_version).to eq(2525)
      end
    end

    context 'when node.services is present' do
      let(:params) { base_params.merge('node.services' => %w[zoekt]) }

      it 'sets services' do
        expect(tasked_node.services).to eq([
          described_class::SERVICES[:zoekt]
        ])
      end
    end

    context 'when process_health is present', :freeze_time do
      let(:process_health) do
        {
          'indexer' => {
            'mmap_current' => 1234,
            'mmap_max' => 65530,
            'restarts_1m' => 0,
            'restarts_5m' => 0,
            'restarts_15m' => 0,
            'rss_bytes' => 268435456,
            'uptime_seconds' => 3600
          },
          'webserver' => {
            'mmap_current' => 5678,
            'mmap_max' => 65530,
            'restarts_1m' => 0,
            'restarts_5m' => 0,
            'restarts_15m' => 0,
            'rss_bytes' => 536870912,
            'uptime_seconds' => 3600,
            'shards_loaded' => 10
          }
        }
      end

      let(:params) { base_params.merge('process_health' => process_health) }

      it 'stores process_health in metadata' do
        expect(tasked_node.metadata['process_health']).to eq(process_health)
      end

      it 'sets webserver_last_seen_at to now when webserver key is present' do
        expect(tasked_node.webserver_last_seen_at).to eq(Time.zone.now)
      end

      context 'when only indexer data is present (webserver not reporting)' do
        let(:process_health) do
          {
            'indexer' => {
              'mmap_current' => 1234,
              'mmap_max' => 65530,
              'restarts_1m' => 0,
              'restarts_5m' => 0,
              'restarts_15m' => 0,
              'rss_bytes' => 268435456,
              'uptime_seconds' => 3600
            }
          }
        end

        it 'does not update webserver_last_seen_at' do
          expect(tasked_node.webserver_last_seen_at).to be_nil
        end

        it 'still stores indexer data in metadata' do
          expect(tasked_node.metadata['process_health']).to eq(process_health)
        end
      end
    end

    context 'when process_health is absent' do
      let(:params) { base_params }

      it 'does not set process_health in metadata' do
        expect(tasked_node.metadata['process_health']).to be_nil
      end
    end
  end

  describe '.maximum_zoekt_schema_version' do
    let_it_be(:_node1) { create(:zoekt_node, :offline, schema_version: 9999) }
    let_it_be(:_node2) { create(:zoekt_node, schema_version: 2310) }
    let_it_be(:node3) { create(:zoekt_node, schema_version: 2311) }

    it 'returns the maximum schema version among online nodes' do
      expect(described_class.maximum_zoekt_schema_version).to eq(node3.schema_version)
    end
  end

  describe '.all_at_least_version?' do
    it 'caches the result', :use_clean_rails_memory_store_caching do
      node.update!(metadata: node.metadata.merge('version' => '1.9.0'))

      query_count = 0
      allow(described_class).to receive(:for_search).and_wrap_original do |m, *args|
        query_count += 1
        m.call(*args)
      end

      2.times { described_class.all_at_least_version?('1.9.0') }

      expect(query_count).to eq(1)
    end
  end

  describe '.all_at_least_version_uncached?' do
    using RSpec::Parameterized::TableSyntax

    subject(:all_at_least_version_uncached) { described_class.send(:all_at_least_version_uncached?, '1.9.0') }

    # The top-level `node` fixture is online and has no version - give it one so it
    # doesn't interfere with the "all meet requirement" cases.
    before do
      node.update!(metadata: node.metadata.merge('version' => '1.9.0'))
    end

    context 'when all online search nodes meet the version requirement' do
      where(:version_string) do
        [
          ['1.9.0'],
          ['v1.9.0'],
          ['2026.02.18-v1.9.0'],
          ['2026.02.27-v1.9.0-62-g6229205'],
          ['1.9.1'],
          ['v1.9.1'],
          ['1.10.0'],
          ['v1.10.0'],
          ['2.0.0'],
          ['v2.0.0'],
          ['2026.02.27-v2.0.0-62-g6229205']
        ]
      end

      with_them do
        it 'returns true' do
          create(:zoekt_node, metadata: { name: 'node-extra', version: version_string })

          expect(all_at_least_version_uncached).to be(true)
        end
      end
    end

    context 'when some online search nodes do not meet the version requirement' do
      where(:version_string) do
        [
          ['1.8.0'],
          ['v1.8.0'],
          ['2026.02.18-v1.8.0'],
          ['2026.02.27-v1.8.0-62-g6229205'],
          ['1.8.9'],
          ['0.9.0']
        ]
      end

      with_them do
        it 'returns false' do
          create(:zoekt_node, metadata: { name: 'node-extra', version: version_string })

          expect(all_at_least_version_uncached).to be(false)
        end
      end
    end

    context 'when a node has no version in metadata' do
      it 'returns false' do
        node.update!(metadata: { 'name' => 'node-1' })

        expect(all_at_least_version_uncached).to be(false)
      end
    end

    context 'when a node has a version string that does not match the expected semver pattern' do
      it 'returns false' do
        node.update!(metadata: { 'name' => 'node-1', 'version' => 'garbage' })

        expect(all_at_least_version_uncached).to be(false)
      end
    end

    context 'when one node meets the requirement and another does not' do
      it 'returns false' do
        create(:zoekt_node, metadata: { name: 'node-extra', version: '1.8.0' })

        expect(all_at_least_version_uncached).to be(false)
      end
    end

    context 'when an offline node does not meet the requirement' do
      it 'ignores offline nodes and returns true' do
        create(:zoekt_node, :offline, metadata: { name: 'node-extra', version: '1.8.0' })

        expect(all_at_least_version_uncached).to be(true)
      end
    end
  end

  describe '.needs_reindex' do
    let_it_be(:node) { create(:zoekt_node, :offline, schema_version: 9955) }
    let_it_be(:node2) { create(:zoekt_node, schema_version: 9955) }
    let_it_be(:node3) { create(:zoekt_node, schema_version: 9955) }
    let_it_be(:node4) { create(:zoekt_node, schema_version: 9955) }
    let_it_be(:node5) { create(:zoekt_node, schema_version: 9955) }
    let_it_be(:node6) { create(:zoekt_node, schema_version: 9955) }
    let_it_be(:index_offline_node) { create(:zoekt_index, node: node) }
    let_it_be(:_index_without_repos) { create(:zoekt_index, node: node2) }
    let_it_be(:index_without_indexable_repo) { create(:zoekt_index, node: node3) }
    let_it_be(:index_with_repos_low_schema_version) { create(:zoekt_index, node: node4) }
    let_it_be(:index_with_repos_low_schema_version2) { create(:zoekt_index, node: node5) }
    let_it_be(:index_with_repos_high_schema_version) { create(:zoekt_index, node: node6) }

    before_all do
      create(:zoekt_repository, zoekt_index: index_offline_node)
      create(:zoekt_repository, :orphaned, zoekt_index: index_without_indexable_repo)
      create(:zoekt_repository, zoekt_index: index_with_repos_low_schema_version)
      create(:zoekt_repository, zoekt_index: index_with_repos_low_schema_version2)
      create(:zoekt_repository, zoekt_index: index_with_repos_high_schema_version, schema_version: 9956)
    end

    context 'when limit is not nil' do
      it 'returns the limited nodes that needs reindex' do
        expect(described_class.needs_reindex(1)).to match_array([node4])
      end
    end

    context 'when limit is nil' do
      it 'returns all nodes that needs reindex' do
        expect(described_class.needs_reindex).to match_array([node4, node5])
      end
    end
  end

  describe '.replica_map_for_enabled_namespace' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }
    let_it_be(:node1) { create(:zoekt_node) }
    let_it_be(:node2) { create(:zoekt_node) }
    let_it_be(:node3) { create(:zoekt_node) }

    subject(:replica_map) { described_class.replica_map_for_enabled_namespace(enabled_namespace) }

    context 'when there are no replicas' do
      it 'returns an empty hash' do
        expect(replica_map).to eq({})
      end
    end

    context 'when there is one replica with one node' do
      let_it_be(:replica1) { create(:zoekt_replica, :ready, zoekt_enabled_namespace: enabled_namespace) }
      let_it_be(:_index1) do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica1, node: node1)
      end

      it 'returns a hash with the replica_id mapping to an array with one node' do
        expect(replica_map).to eq({ replica1.id => [node1] })
      end
    end

    context 'when there is one replica with multiple nodes' do
      let_it_be(:replica1) { create(:zoekt_replica, :ready, zoekt_enabled_namespace: enabled_namespace) }
      let_it_be(:_index1) do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica1, node: node1)
      end

      let_it_be(:_index2) do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica1, node: node2)
      end

      it 'returns a hash with the replica_id mapping to an array with multiple nodes' do
        expect(replica_map[replica1.id]).to contain_exactly(node1, node2)
      end
    end

    context 'when there are multiple replicas with different nodes' do
      let_it_be(:replica1) { create(:zoekt_replica, :ready, zoekt_enabled_namespace: enabled_namespace) }
      let_it_be(:replica2) { create(:zoekt_replica, :ready, zoekt_enabled_namespace: enabled_namespace) }
      let_it_be(:_index1) do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica1, node: node1)
      end

      let_it_be(:_index2) do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica1, node: node2)
      end

      let_it_be(:_index3) do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica2, node: node3)
      end

      it 'returns a hash mapping each replica_id to its nodes' do
        expect(replica_map.keys).to contain_exactly(replica1.id, replica2.id)
        expect(replica_map[replica1.id]).to contain_exactly(node1, node2)
        expect(replica_map[replica2.id]).to contain_exactly(node3)
      end
    end

    context 'when there are non-ready replicas' do
      let_it_be(:replica_ready) { create(:zoekt_replica, :ready, zoekt_enabled_namespace: enabled_namespace) }
      let_it_be(:replica_pending) { create(:zoekt_replica, :pending, zoekt_enabled_namespace: enabled_namespace) }
      let_it_be(:index_ready) do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica_ready, node: node1)
      end

      let_it_be(:index_pending) do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica_pending, node: node2)
      end

      it 'returns only ready replicas' do
        expect(replica_map.keys).to contain_exactly(replica_ready.id)
        expect(replica_map[replica_ready.id]).to contain_exactly(node1)
        expect(replica_map).not_to have_key(replica_pending.id)
      end
    end

    context 'when a node serves multiple replicas' do
      let_it_be(:another_enabled_namespace) { create(:zoekt_enabled_namespace) }
      let_it_be(:replica1) { create(:zoekt_replica, :ready, zoekt_enabled_namespace: enabled_namespace) }
      let_it_be(:replica2) { create(:zoekt_replica, :ready, zoekt_enabled_namespace: another_enabled_namespace) }
      let_it_be(:index1) do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica1, node: node1)
      end

      let_it_be(:index2) do
        create(:zoekt_index, zoekt_enabled_namespace: another_enabled_namespace, replica: replica2, node: node1)
      end

      it 'returns nodes for only the specified enabled namespace' do
        expect(replica_map[replica1.id]).to contain_exactly(node1)
        expect(replica_map).not_to have_key(replica2.id)
      end
    end

    context 'when the method is called on a scoped relation' do
      let_it_be(:replica1) { create(:zoekt_replica, :ready, zoekt_enabled_namespace: enabled_namespace) }
      let_it_be(:_index1) do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica1, node: node1)
      end

      it 'respects the caller scope' do
        # Call on a scope that filters to a specific node
        scoped_map = described_class.id_in(node1.id).replica_map_for_enabled_namespace(enabled_namespace)

        expect(scoped_map[replica1.id]).to contain_exactly(node1)
      end

      it 'excludes nodes not in the caller scope' do
        # Create another index with a different node
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica1, node: node2)

        # Call on a scope that only includes node1
        scoped_map = described_class.id_in(node1.id).replica_map_for_enabled_namespace(enabled_namespace)

        expect(scoped_map[replica1.id]).to contain_exactly(node1)
        expect(scoped_map[replica1.id]).not_to include(node2)
      end
    end
  end

  describe '.marking_lost_enabled?', :zoekt_settings_enabled do
    before do
      allow(::Search::Zoekt::Settings).to receive(:lost_node_threshold).and_return(12.hours)
    end

    it 'returns true' do
      expect(described_class.marking_lost_enabled?).to be true
    end

    context 'when application setting zoekt_indexing_paused? is enabled' do
      before do
        stub_ee_application_setting(zoekt_indexing_paused: true)
      end

      it 'returns false' do
        expect(described_class.marking_lost_enabled?).to be false
      end
    end

    context 'when application setting zoekt_indexing_enabled? is disabled' do
      before do
        stub_ee_application_setting(zoekt_indexing_enabled: false)
      end

      it 'returns false' do
        expect(described_class.marking_lost_enabled?).to be false
      end
    end

    context 'when application setting zoekt_lost_node_threshold is disabled' do
      before do
        allow(::Search::Zoekt::Settings).to receive(:lost_node_threshold).and_return(nil)
      end

      it 'returns false' do
        expect(described_class.marking_lost_enabled?).to be false
      end
    end
  end

  describe '#metadata_json' do
    it 'returns a json with metadata' do
      node.update!(metadata: { name: 'test_name', task_count: 100, concurrency: 10, version: '2.0.0' })
      expected_json = {
        'zoekt.node_name' => 'test_name',
        'zoekt.node_id' => node.id,
        'zoekt.indexed_bytes' => 0,
        'zoekt.storage_percent_used' => node.storage_percent_used,
        'zoekt.used_bytes' => node.used_bytes,
        'zoekt.total_bytes' => node.total_bytes,
        'zoekt.task_count' => 100,
        'zoekt.concurrency' => 10,
        'zoekt.concurrency_limit' => 10,
        'zoekt.version' => '2.0.0'
      }

      expect(node.metadata_json).to eq(expected_json)
    end

    it 'does not return empty keys' do
      node.update!(metadata: { name: 'another_name' })
      expected_json = {
        'zoekt.node_name' => 'another_name',
        'zoekt.node_id' => node.id,
        'zoekt.indexed_bytes' => 0,
        'zoekt.storage_percent_used' => node.storage_percent_used,
        'zoekt.used_bytes' => node.used_bytes,
        'zoekt.total_bytes' => node.total_bytes,
        'zoekt.concurrency_limit' => node.concurrency_limit
      }

      expect(node.metadata_json).to eq(expected_json)
    end
  end

  describe '#concurrency_limit' do
    subject(:concurrency_limit) { node.concurrency_limit }

    context 'when node does not have task_count/concurrency set' do
      it 'returns the default limit' do
        expect(concurrency_limit).to eq(described_class::DEFAULT_CONCURRENCY_LIMIT)
      end
    end

    context 'when node has task_count/concurrency set' do
      using RSpec::Parameterized::TableSyntax

      where(:concurrency, :concurrency_override, :multiplier, :result) do
        10  | nil | 1.0 | 10
        10  | nil | 1.5 | 15
        10  | nil | 2.0 | 20
        10  | 0   | 3.5 | 35
        3   | 0   | 2.5 | 8
        3   | 0   | 2.4 | 7
        1   | nil | 1.0 | 1
        1   | nil | 2.0 | 2
        10  | 20  | 1.5 | 20
        200 | nil | 1.0 | described_class::MAX_CONCURRENCY_LIMIT
        200 | nil | 1.5 | described_class::MAX_CONCURRENCY_LIMIT
        0   | nil | 1.5 | described_class::DEFAULT_CONCURRENCY_LIMIT
      end

      with_them do
        before do
          stub_ee_application_setting(zoekt_cpu_to_tasks_ratio: multiplier)
          node.metadata['concurrency'] = concurrency
          node.metadata['concurrency_override'] = concurrency_override
        end

        it 'returns correct value' do
          expect(concurrency_limit).to eq(result)
        end
      end
    end
  end

  describe '#storage_percent_used' do
    it 'is used storage / total reserved storage' do
      expect(node.storage_percent_used).to eq(node.used_bytes / node.total_bytes.to_f)
    end
  end

  describe '.mmap_usage_level' do
    using RSpec::Parameterized::TableSyntax

    where(:mmap_current, :mmap_max, :expected_level) do
      0       | 0     | :ok
      999_999 | 0     | :ok
      0       | 100   | :ok
      79      | 100   | :ok
      80      | 100   | :warning
      94      | 100   | :warning
      95      | 100   | :critical
      100     | 100   | :critical
    end

    with_them do
      it 'returns the correct level' do
        expect(described_class.mmap_usage_level(mmap_current, mmap_max)).to eq(expected_level)
      end
    end
  end

  describe '#watermark_exceeded_low?' do
    it 'returns true when over low limit' do
      node.used_bytes = 0
      expect(node).not_to be_watermark_exceeded_low

      node.used_bytes = node.total_bytes * described_class::WATERMARK_LIMIT_LOW
      expect(node).to be_watermark_exceeded_low
      expect(node).not_to be_watermark_exceeded_high
      expect(node).not_to be_watermark_exceeded_critical
    end
  end

  describe '#watermark_exceeded_high?' do
    it 'returns true when over high limit' do
      node.used_bytes = 0
      expect(node).not_to be_watermark_exceeded_high

      node.used_bytes = node.total_bytes * described_class::WATERMARK_LIMIT_HIGH
      expect(node).to be_watermark_exceeded_low
      expect(node).to be_watermark_exceeded_high
      expect(node).not_to be_watermark_exceeded_critical
    end
  end

  describe '#unclaimed_storage_bytes' do
    let(:test_node) { create(:zoekt_node) }

    it 'returns the difference between usable and reserved storage' do
      test_node.update!(total_bytes: 1000, used_bytes: 300, indexed_bytes: 200)
      test_node.save! # This triggers update_usable_storage_bytes

      allow(test_node).to receive(:reserved_storage_bytes).and_return(300)

      # usable_storage_bytes should be free_bytes + indexed_bytes = (1000 - 300) + 200 = 900
      # unclaimed_storage_bytes should be usable_storage_bytes - reserved_storage_bytes = 900 - 300 = 600
      expect(test_node.unclaimed_storage_bytes).to eq(600)
    end

    it 'returns usable_storage_bytes when there are no reserved bytes' do
      test_node.update!(total_bytes: 1000, used_bytes: 300, indexed_bytes: 200)
      test_node.save! # This triggers update_usable_storage_bytes

      allow(test_node).to receive(:reserved_storage_bytes).and_return(0)

      # usable_storage_bytes should be free_bytes + indexed_bytes = (1000 - 300) + 200 = 900
      # unclaimed_storage_bytes should be usable_storage_bytes - reserved_storage_bytes = 900 - 0 = 900
      expect(test_node.unclaimed_storage_bytes).to eq(900)
    end
  end

  describe '#reserved_storage_bytes_cache=' do
    let(:test_node) { create(:zoekt_node) }

    it 'makes unclaimed_storage_bytes use the cached value instead of querying' do
      test_node.reserved_storage_bytes_cache = 500

      expect(test_node.unclaimed_storage_bytes).to eq(test_node.usable_storage_bytes - 500)
    end

    it 'falls back to DB query when cache is not set' do
      create(:zoekt_index, node: test_node, reserved_storage_bytes: 100)

      expect(test_node.unclaimed_storage_bytes).to eq(test_node.usable_storage_bytes - 100)
    end
  end

  describe '#adjust_reserved_storage_bytes_cache' do
    let(:test_node) { create(:zoekt_node) }

    context 'when cache is set' do
      before do
        test_node.reserved_storage_bytes_cache = 1000
      end

      it 'adjusts the cached value by the given delta' do
        test_node.adjust_reserved_storage_bytes_cache(200)

        expect(test_node.unclaimed_storage_bytes).to eq(test_node.usable_storage_bytes - 1200)
      end

      it 'handles negative deltas' do
        test_node.adjust_reserved_storage_bytes_cache(-300)

        expect(test_node.unclaimed_storage_bytes).to eq(test_node.usable_storage_bytes - 700)
      end
    end

    context 'when cache is not set' do
      it 'does not raise an error' do
        expect { test_node.adjust_reserved_storage_bytes_cache(200) }.not_to raise_error
      end
    end
  end

  describe '#watermark_exceeded_critical?' do
    it 'returns true when over critical limit' do
      node.used_bytes = 0
      expect(node).not_to be_watermark_exceeded_critical

      node.used_bytes = node.total_bytes * described_class::WATERMARK_LIMIT_CRITICAL
      expect(node).to be_watermark_exceeded_low
      expect(node).to be_watermark_exceeded_high
      expect(node).to be_watermark_exceeded_critical
    end
  end

  describe '#task_pull_frequency' do
    before do
      node.metadata['concurrency_override'] = 1
      node.save!
    end

    context 'when pending tasks is more than the concurrency_limit of a node' do
      before do
        create_list(:zoekt_task, 2, node: node)
      end

      it 'returns increased pull frequency' do
        expect(node.task_pull_frequency).to eq described_class::TASK_PULL_FREQUENCY_INCREASED
      end
    end

    context 'when pending tasks is equal to the concurrency_limit of a node' do
      before do
        create(:zoekt_task, node: node)
      end

      it 'returns increased pull frequency' do
        expect(node.task_pull_frequency).to eq described_class::TASK_PULL_FREQUENCY_INCREASED
      end
    end

    context 'when pending tasks is less than the concurrency_limit of a node' do
      it 'returns default pull frequency' do
        expect(node.task_pull_frequency).to eq described_class::TASK_PULL_FREQUENCY_DEFAULT
      end
    end
  end

  describe '#save_debounce', :freeze_time do
    context 'when record is persisted' do
      context 'when difference between updated_at and current time is more than DEBOUNCE_DELAY' do
        before do
          node.update_column :updated_at, (described_class::DEBOUNCE_DELAY + 1.second).ago
        end

        it 'returns true and calls save' do
          expect(node).to receive(:save).and_call_original
          expect(node.save_debounce).to be true
        end
      end

      context 'when difference between updated_at and current time is less than DEBOUNCE_DELAY' do
        before do
          node.update_column :updated_at, (described_class::DEBOUNCE_DELAY - 1.second).ago
        end

        it 'returns true and does not calls save' do
          expect(node).not_to receive(:save)
          expect(node.save_debounce).to be true
        end
      end
    end

    context 'when record is not persisted' do
      let(:new_node) { build(:zoekt_node) }

      it 'calls save' do
        expect(new_node).to receive(:save)
        new_node.save_debounce
      end
    end
  end

  describe '#usable_storage_bytes' do
    let_it_be_with_reload(:test_node) { create(:zoekt_node) }

    before do
      test_node.update!(total_bytes: 1000, used_bytes: 300, indexed_bytes: 200)
    end

    it 'must be a numerical value' do
      expect(test_node).to be_valid

      test_node.usable_storage_bytes = 'foo'
      expect(test_node).not_to be_valid
    end

    it 'must not be nil' do
      expect(test_node).to be_valid
      test_node.usable_storage_bytes = nil
      test_node.total_bytes = nil
      test_node.used_bytes = nil
      test_node.indexed_bytes = nil
      expect(test_node).not_to be_valid
    end

    it 'is set to free_bytes plus indexed_bytes on save' do
      test_node.save!
      expect(test_node.usable_storage_bytes).to eq(900) # (1000 - 300) + 200
    end
  end
end
