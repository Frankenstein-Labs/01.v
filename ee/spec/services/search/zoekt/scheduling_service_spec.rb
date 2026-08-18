# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::SchedulingService, :clean_gitlab_redis_shared_state, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }
  let(:service) { described_class.new(task.to_s) }
  let_it_be_with_reload(:node) { create(:zoekt_node, :enough_free_space) }

  subject(:execute_task) { service.execute }

  before do
    allow(described_class).to receive(:logger).and_return(logger)
  end

  shared_examples 'a execute_every task' do |opts = {}|
    let(:redis_spy) { instance_spy(Redis) }
    let(:period) { opts[:period] }

    it 'uses cache when given a cache period', :clean_gitlab_redis_shared_state do
      allow(Gitlab::Redis::SharedState).to receive(:with).and_yield(redis_spy)
      service.execute

      if period.present?
        expect(redis_spy).to have_received(:set).with(service.cache_key, 1, ex: period, nx: true)
      else
        expect(redis_spy).not_to have_received(:set).with(service.cache_key, anything, anything)
      end
    end

    context 'when on development environment', :clean_gitlab_redis_shared_state do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it 'does not use cache' do
        expect(Gitlab::Redis::SharedState).not_to receive(:with)
      end
    end
  end

  describe 'TASKS' do
    it 'includes the keys from CONFIG' do
      described_class::CONFIG.each_key do |key|
        expect(described_class::TASKS.include?(key)).to be_truthy
      end
    end

    described_class::CONFIG.each do |key, opts|
      context "with proper cache period for dispatch task '#{key}'" do
        let(:task) { key }

        it_behaves_like 'a execute_every task', period: opts[:period]
      end
    end
  end

  describe '.execute' do
    let(:task) { :foo }

    it 'executes the task' do
      expect(described_class).to receive(:new).with(task).and_return(service)
      expect(service).to receive(:execute)

      described_class.execute(task)
    end

    context 'when passed without_cache argument' do
      let(:redis) { instance_double(Redis) }

      it 'removes the cache key before executing the task' do
        expect(Gitlab::Redis::SharedState).to receive(:with).and_yield(redis)
        expect(redis).to receive(:del).with(service.cache_key)

        expect(described_class).to receive(:new).with(task).and_return(service)
        expect(service).to receive(:execute)

        described_class.execute(task, without_cache: true)
      end
    end
  end

  describe '.execute!' do
    let(:task) { :foo }

    it 'calls .execute specifying without_cache' do
      expect(described_class).to receive(:execute).with(task, without_cache: true)

      described_class.execute!(task)
    end
  end

  describe '#execute' do
    let(:task) { :foo }

    it 'raises an exception when unknown task is provided' do
      expect { service.execute }.to raise_error(ArgumentError)
    end

    it 'raises an exception when the task is not implemented' do
      stub_const('::Search::Zoekt::SchedulingService::TASKS', [:foo])

      expect { service.execute }.to raise_error(NotImplementedError)
    end

    it 'converts string task to symbol' do
      expect(described_class.new(task.to_s).task).to eq(task.to_sym)
    end
  end

  describe '#cache_key' do
    context 'with tasks that have empty cache periods' do
      it 'is formatted correctly based on task name' do
        %i[foo bar baz].each do |task|
          expect(described_class.new(task).cache_key).to eq("search/zoekt/scheduling_service:execute_every:-:#{task}")
        end
      end
    end

    context 'with tasks that have cache periods configured' do
      it 'is formatted correctly based on task name and cache period' do
        %i[lost_nodes_check].each do |task|
          svc = described_class.new(task)
          expect(svc.cache_key).to eq("search/zoekt/scheduling_service:execute_every:#{svc.cache_period}:#{task}")
        end
      end
    end
  end

  describe '#cache_period' do
    context 'with a task from CONFIG' do
      it 'returns the period when configured' do
        expect(described_class.new(:lost_nodes_check).cache_period).to eq(10.minutes)
      end

      it 'returns nil when not configured' do
        expect(described_class.new(:mark_indices_as_ready).cache_period).to be_nil
      end
    end

    context 'with a task not from CONFIG' do
      it 'returns nil' do
        expect(described_class.new(:foo).cache_period).to be_nil
      end
    end
  end

  describe '#eviction' do
    let(:logger) { instance_double(::Search::Zoekt::Logger) }
    let(:task) { :eviction }

    before do
      allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
    end

    it 'returns false unless saas' do
      expect(execute_task).to be(false)
    end

    context 'when on .com', :saas do
      let_it_be(:zoekt_index) { create(:zoekt_index, node: node) }

      context 'when nodes have enough storage' do
        it 'returns false' do
          expect(logger).not_to receive(:info)
          expect { execute_task }.not_to change { Search::Zoekt::Replica.count }
        end
      end

      context 'when nodes are over the watermark high limit' do
        let_it_be(:node_out_of_storage) { create(:zoekt_node, :not_enough_free_space) }
        let_it_be_with_reload(:namespace_statistics) do
          create(:namespace_root_storage_statistics, repository_size: node_out_of_storage.used_bytes * 0.7)
        end

        let_it_be_with_reload(:ns) { create(:group, root_storage_statistics: namespace_statistics) }
        let_it_be(:enabled_ns) { create(:zoekt_enabled_namespace, namespace: ns) }
        let_it_be(:zoekt_index2) do
          create(:zoekt_index, node: node_out_of_storage,
            zoekt_enabled_namespace: enabled_ns,
            used_storage_bytes: node_out_of_storage.used_bytes)
        end

        it 'removes extra indices and logs' do
          expect(logger).to receive(:info).with({ 'class' => described_class.to_s, 'task' => task,
            'message' => 'Detected nodes over watermark',
            'watermark_limit_high' => ::Search::Zoekt::Node::WATERMARK_LIMIT_HIGH,
            'count' => 1 }
          )

          expect(logger).to receive(:info).with({ 'class' => described_class.to_s, 'task' => task,
            'message' => 'Unassigning namespaces from node',
            'watermark_limit_high' => ::Search::Zoekt::Node::WATERMARK_LIMIT_HIGH,
            'count' => 1,
            'node_used_bytes' => 90000000,
            'node_expected_used_bytes' => 27000001,
            'total_repository_size' => namespace_statistics.repository_size,
            'meta' => node_out_of_storage.metadata_json.merge(
              'zoekt.used_bytes' => 27000001, 'zoekt.storage_percent_used' => 0.27000001) }
          )

          expect { execute_task }.to change { Search::Zoekt::Replica.count }.from(2).to(1)
          expect(enabled_ns.reload.metadata['last_used_storage_bytes']).to eq(node_out_of_storage.used_bytes)
        end

        it 'keeps search enabled for the enabled namespace' do
          allow(logger).to receive(:info)
          expect { execute_task }.not_to change { zoekt_index2.zoekt_enabled_namespace.reload.search }
        end
      end
    end
  end

  describe '#index_mismatched_watermark_check' do
    let(:task) { :index_mismatched_watermark_check }
    let(:logger) { instance_double(Logger) }

    before do
      allow_next_instance_of(described_class) do |instance|
        allow(instance).to receive(:logger).and_return(logger)
        allow(instance).to receive(:build_structured_payload) do |**payload|
          payload
        end
      end

      allow(logger).to receive(:info)
    end

    context 'when there are no indices with mismatched watermark levels' do
      before do
        allow(Search::Zoekt::Index).to receive_message_chain(:with_mismatched_watermark_levels, :exists?)
          .and_return(false)
      end

      it 'returns false' do
        expect(execute_task).to be false
      end
    end

    context 'when there are indices with mismatched watermark levels' do
      before do
        allow(Search::Zoekt::Index).to receive_message_chain(:with_mismatched_watermark_levels, :exists?)
          .and_return(true)
        allow(Search::Zoekt::Index).to receive_message_chain(:with_mismatched_watermark_levels, :count)
          .and_return(5)
      end

      it 'logs a message with the count of mismatched indices' do
        expected_payload = {
          task: :index_mismatched_watermark_check,
          message: 'Detected indices with mismatched watermarks',
          count: 5
        }

        execute_task

        expect(logger).to have_received(:info).with(expected_payload)
      end

      it_behaves_like 'a execute_every task', period: 10.minutes
    end
  end

  describe '#remove_expired_subscriptions' do
    let(:task) { :remove_expired_subscriptions }

    it 'returns false unless saas' do
      expect(execute_task).to be(false)
    end

    context 'when on development environment' do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it 'returns false' do
        expect(execute_task).to be(false)
      end
    end

    context 'when on .com', :saas do
      let_it_be(:expiration_date) { Time.zone.today - Search::Zoekt::EXPIRED_SUBSCRIPTION_GRACE_PERIOD }
      let_it_be(:zkt_enabled_namespace) { create(:zoekt_enabled_namespace) }
      let_it_be(:zkt_enabled_namespace2) { create(:zoekt_enabled_namespace) }
      let_it_be(:subscription) { create(:gitlab_subscription, namespace: zkt_enabled_namespace2.namespace) }
      let_it_be(:expired_subscription) do
        create(:gitlab_subscription, namespace: zkt_enabled_namespace.namespace, end_date: expiration_date - 1.day)
      end

      it 'destroys zoekt_namespaces with expired subscriptions' do
        expect { execute_task }.to change { ::Search::Zoekt::EnabledNamespace.count }.by(-1)

        expect(::Search::Zoekt::EnabledNamespace.pluck(:id)).to contain_exactly(zkt_enabled_namespace2.id)
      end
    end
  end

  describe '#mark_indices_as_ready' do
    let(:logger) { instance_double(::Search::Zoekt::Logger) }
    let(:task) { :mark_indices_as_ready }

    before do
      create(:zoekt_index, :ready)
      create(:zoekt_index, state: :pending)
      create(:zoekt_index, state: :in_progress)
      create(:zoekt_index, state: :reallocating)
      create(:zoekt_index, state: :orphaned)
      create(:zoekt_index, state: :pending_deletion)
    end

    context 'when there are no initializing indices' do
      before do
        allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
      end

      it 'does not publish any event' do
        expect { execute_task }.not_to publish_event(Search::Zoekt::IndexMarkedAsReadyEvent)
      end
    end

    context 'when there are initializing indices' do
      before do
        create(:zoekt_index, state: :initializing)
      end

      it 'publishes Search::Zoekt::IndexMarkedAsReadyEvent event' do
        expect { execute_task }.to publish_event(Search::Zoekt::IndexMarkedAsReadyEvent).with(Hash.new({}))
      end
    end
  end

  describe '#initial_indexing' do
    let(:task) { :initial_indexing }
    let_it_be_with_reload(:online_node) { create(:zoekt_node) }
    let_it_be_with_reload(:offline_node) { create(:zoekt_node, :offline) }
    let_it_be_with_reload(:index1) { create(:zoekt_index, state: :pending, node: online_node) }
    let_it_be_with_reload(:index2) { create(:zoekt_index, state: :pending, node: online_node) }
    let_it_be_with_reload(:index3) { create(:zoekt_index, state: :pending, node: offline_node) }

    context 'when there are no zoekt_indices in pending state' do
      before do
        Search::Zoekt::Index.update_all(state: :initializing)
      end

      it 'does not publish the event Search::Zoekt::InitialIndexingEvent' do
        expect { execute_task }.not_to publish_event(Search::Zoekt::InitialIndexingEvent)
      end
    end

    context 'when there are pending indices on online nodes' do
      before do
        stub_const "#{described_class}::INITIAL_INDEXING_LIMIT", 5
      end

      it 'publishes the event Search::Zoekt::InitialIndexingEvent for pending indices on online nodes' do
        expect { execute_task }.to publish_event(Search::Zoekt::InitialIndexingEvent)
          .with({ index_id: index1.id }).and publish_event(Search::Zoekt::InitialIndexingEvent)
          .with({ index_id: index2.id })
      end

      it 'does not publish events for pending indices on offline nodes' do
        allow(Search::Zoekt::Node).to receive(:online).and_return(Search::Zoekt::Node.where(id: online_node.id))

        # Double check that our offline node's index is not processed
        expect { execute_task }.not_to publish_event(Search::Zoekt::InitialIndexingEvent)
          .with({ index_id: index3.id })
      end
    end

    context 'when there are more pending indices than the limit per node' do
      let_it_be(:indices) do
        create_list(:zoekt_index, described_class::INITIAL_INDEXING_LIMIT, state: :pending, node: online_node)
      end

      let_it_be(:extra_index) do
        create(:zoekt_index, state: :pending, node: online_node)
      end

      it 'respects the INITIAL_INDEXING_LIMIT per node' do
        # We should process INITIAL_INDEXING_LIMIT indices and not process the extra one
        expect { execute_task }.not_to publish_event(Search::Zoekt::InitialIndexingEvent)
          .with({ index_id: extra_index.id })
      end
    end

    context 'with multiple nodes having pending indices' do
      before do
        stub_const "#{described_class}::INITIAL_INDEXING_LIMIT", 5
      end

      let_it_be_with_reload(:another_online_node) { create(:zoekt_node) }
      let_it_be_with_reload(:another_index) { create(:zoekt_index, state: :pending, node: another_online_node) }

      it 'processes pending indices for each node up to the limit' do
        expect { execute_task }.to publish_event(Search::Zoekt::InitialIndexingEvent)
          .with({ index_id: index1.id }).and publish_event(Search::Zoekt::InitialIndexingEvent)
          .with({ index_id: index2.id }).and publish_event(Search::Zoekt::InitialIndexingEvent)
          .with({ index_id: another_index.id })
      end
    end
  end

  describe '#auto_index_self_managed' do
    let(:task) { :auto_index_self_managed }
    let_it_be(:sub_group) { create(:group, :nested) }
    let_it_be(:top_group) { create(:group) }
    let_it_be(:top_group2) { create(:group) }
    let(:user_namespace) { Namespaces::UserNamespace.last }

    before do
      stub_ee_application_setting(zoekt_auto_index_root_namespace: true)
      create(:zoekt_enabled_namespace, root_namespace_id: top_group2.id)
    end

    context 'for gitlab.com', :saas do
      it 'does not create any record of Search::Zoekt::EnabledNamespace' do
        expect { execute_task }.not_to change { Search::Zoekt::EnabledNamespace.count }
      end
    end

    context 'when application setting zoekt_auto_index_root_namespace is false' do
      before do
        stub_ee_application_setting(zoekt_auto_index_root_namespace: false)
      end

      it 'does not create any record of Search::Zoekt::EnabledNamespace' do
        expect { execute_task }.not_to change { Search::Zoekt::EnabledNamespace.count }
      end
    end

    it "creates zoekt_enabled_namespace for the root namespaces that don't have zoekt_enabled_namespace already" do
      expect(user_namespace.zoekt_enabled_namespace).to be_nil
      expect(sub_group.root_ancestor.zoekt_enabled_namespace).to be_nil
      expect(top_group.zoekt_enabled_namespace).to be_nil
      expect(top_group2.zoekt_enabled_namespace).not_to be_nil

      expect { execute_task }.to change { Search::Zoekt::EnabledNamespace.count }.by(3)
      expect(sub_group.root_ancestor.reload.zoekt_enabled_namespace).not_to be_nil
      expect(top_group.reload.zoekt_enabled_namespace).not_to be_nil
      expect(user_namespace.reload.zoekt_enabled_namespace).not_to be_nil
    end
  end

  describe '#update_replica_states' do
    let(:task) { :update_replica_states }

    it 'calls ReplicaStateService.execute' do
      expect(::Search::Zoekt::ReplicaStateService).to receive(:execute)
      execute_task
    end
  end

  describe '#update_index_used_storage_bytes' do
    let(:task) { :update_index_used_storage_bytes }
    let_it_be(:index) { create(:zoekt_index, :ready) }
    let_it_be(:repo) { create(:zoekt_repository, zoekt_index: index) }
    let_it_be(:another_repo) { create(:zoekt_repository, zoekt_index: index) }

    context 'when indices exists in with_stale_used_storage_bytes_updated_at' do
      it 'publishes an UpdateIndexUsedStorageBytesEvent' do
        expect(Search::Zoekt::Index).to receive_message_chain(:with_stale_used_storage_bytes_updated_at, :exists?)
          .and_return(true)
        expect { execute_task }.to publish_event(Search::Zoekt::UpdateIndexUsedStorageBytesEvent).with({})
      end
    end

    context 'when no indices exist in with_stale_used_storage_bytes_updated_at' do
      it 'does not publish an event' do
        expect(Search::Zoekt::Index).to receive_message_chain(:with_stale_used_storage_bytes_updated_at, :exists?)
          .and_return(false)
        expect { execute_task }.not_to publish_event(Search::Zoekt::UpdateIndexUsedStorageBytesEvent)
      end
    end
  end

  describe '#index_should_be_marked_as_orphaned_check' do
    let(:task) { :index_should_be_marked_as_orphaned_check }
    let_it_be_with_reload(:index) { create(:zoekt_index) }

    context 'when there are no indices that should be marked as orphaned' do
      before do
        allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
      end

      it 'does not publish any event' do
        expect { execute_task }.not_to publish_event(Search::Zoekt::OrphanedIndexEvent)
      end
    end

    context 'when there are indices that should be marked as orphaned' do
      before do
        index.update_column(:zoekt_replica_id, nil)
      end

      it 'publishes Search::Zoekt::OrphanedIndexEvent event' do
        expect { execute_task }.to publish_event(Search::Zoekt::OrphanedIndexEvent).with(Hash.new({}))
      end
    end
  end

  describe '#index_to_delete_check' do
    let(:task) { :index_to_delete_check }

    context 'when indices exist in should_be_deleted scope' do
      it 'publishes an IndexMarkedAsToDeleteEvent' do
        expect(Search::Zoekt::Index).to receive_message_chain(:should_be_deleted, :exists?).and_return(true)

        expect { execute_task }
          .to publish_event(Search::Zoekt::IndexMarkedAsToDeleteEvent).with({})
      end
    end

    context 'when no indices exist in should_be_deleted_scope' do
      it 'does not publish an event' do
        expect(Search::Zoekt::Index).to receive_message_chain(:should_be_deleted, :exists?).and_return(false)

        expect { execute_task }.not_to publish_event(Search::Zoekt::IndexMarkedAsToDeleteEvent)
      end
    end
  end

  describe '#repo_should_be_marked_as_orphaned_check' do
    let(:task) { :repo_should_be_marked_as_orphaned_check }

    context 'when repositories exist in should_be_marked_as_orphaned scope' do
      it 'publishes an OrphanedRepoEvent' do
        expect(Search::Zoekt::Repository).to receive_message_chain(:should_be_marked_as_orphaned, :exists?)
                                         .and_return(true)

        expect { execute_task }
          .to publish_event(Search::Zoekt::OrphanedRepoEvent).with({})
      end
    end

    context 'when no repositories exist in should_be_marked_as_orphaned scope' do
      it 'does not publish an event' do
        expect(Search::Zoekt::Repository).to receive_message_chain(:should_be_marked_as_orphaned, :exists?)
                                         .and_return(false)

        expect { execute_task }.not_to publish_event(Search::Zoekt::OrphanedRepoEvent)
      end
    end
  end

  describe '#repo_to_delete_check' do
    let(:task) { :repo_to_delete_check }

    it 'publishes an RepoMarkedAsToDeleteEvent with repos that should be deleted' do
      expect(Search::Zoekt::Repository).to receive_message_chain(:should_be_deleted, :exists?).and_return(true)
      expect { execute_task }.to publish_event(Search::Zoekt::RepoMarkedAsToDeleteEvent).with({})
    end

    context 'when no repositories exist in should_be_deleted scope' do
      it 'does not publish an event' do
        expect(Search::Zoekt::Repository).to receive_message_chain(:should_be_deleted, :exists?).and_return(false)
        expect { execute_task }.not_to publish_event(Search::Zoekt::RepoMarkedAsToDeleteEvent)
      end
    end
  end

  describe '#lost_nodes_check', :zoekt_settings_enabled do
    let(:task) { :lost_nodes_check }
    let_it_be_with_reload(:lost_node) { create(:zoekt_node, :lost) }

    before do
      create(:zoekt_node)
      allow(::Search::Zoekt::Settings).to receive(:lost_node_threshold).and_return(12.hours)
    end

    it 'publishes LostNodeEvent' do
      expect { execute_task }.to publish_event(Search::Zoekt::LostNodeEvent).with({ zoekt_node_id: lost_node.id })
    end

    context 'when there are no lost nodes' do
      before do
        Search::Zoekt::Node.update_all(last_seen_at: Time.current)
      end

      it 'does not publish LostNodeEvent' do
        response = nil
        expect { response = execute_task }.to not_publish_event(Search::Zoekt::LostNodeEvent)
        expect(response).to be false
      end
    end

    context 'when on development environment' do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it 'does not publish LostNodeEvent' do
        expect { execute_task }.to not_publish_event(Search::Zoekt::LostNodeEvent)
      end
    end

    context 'when marking_lost_enabled? is false' do
      before do
        allow(Search::Zoekt::Node).to receive(:marking_lost_enabled?).and_return false
      end

      it 'does not publish LostNodeEvent' do
        expect { execute_task }.to not_publish_event(Search::Zoekt::LostNodeEvent)
      end
    end

    context 'when marking_lost_enabled? is true' do
      before do
        allow(Search::Zoekt::Node).to receive(:marking_lost_enabled?).and_return true
      end

      it 'publishes LostNodeEvent' do
        expect { execute_task }.to publish_event(Search::Zoekt::LostNodeEvent).with({ zoekt_node_id: lost_node.id })
      end
    end

    context 'when all search nodes are lost' do
      before do
        # Mark all existing nodes as lost
        Search::Zoekt::Node.update_all(last_seen_at: 1.day.ago)
        allow(Search::Zoekt::Node).to receive(:marking_lost_enabled?).and_return true
      end

      it 'does not publish LostNodeEvent when all nodes are lost' do
        expect { execute_task }.not_to publish_event(Search::Zoekt::LostNodeEvent)
      end
    end
  end

  describe '#repo_to_index_check' do
    let(:task) { :repo_to_index_check }
    let_it_be(:pending_repo) { create(:zoekt_repository) }
    let_it_be(:initializing_repo) { create(:zoekt_repository, state: :initializing) }
    let_it_be(:ready_repo) { create(:zoekt_repository, state: :ready) }
    let_it_be(:failed_repo) { create(:zoekt_repository, state: :failed) }

    it 'publishes an RepoToIndexEvent with initializing or pending repos' do
      expect { execute_task }.to publish_event(Search::Zoekt::RepoToIndexEvent).with({})
    end

    context 'when there are no repositories needed to be indexed' do
      before do
        allow(Search::Zoekt::Repository).to receive(:should_be_indexed).and_return(Search::Zoekt::Repository.none)
      end

      it 'does not publish an RepoToIndexEvent' do
        expect { execute_task }.not_to publish_event(Search::Zoekt::RepoToIndexEvent)
      end
    end
  end

  describe '#repo_to_reindex_check' do
    let(:task) { :repo_to_reindex_check }
    let_it_be(:node1) { create(:zoekt_node, schema_version: 2) }
    let_it_be(:node2) { create(:zoekt_node, schema_version: 2) }
    let_it_be(:index1) { create(:zoekt_index, node: node1) }
    let_it_be(:index2) { create(:zoekt_index, node: node2) }

    context 'when there are repositories needing reindexing on multiple nodes' do
      before do
        # Create repositories with mismatched schema versions on both nodes
        create(:zoekt_repository, zoekt_index: index1, schema_version: 1, state: :ready)
        create(:zoekt_repository, zoekt_index: index2, schema_version: 1, state: :ready)
      end

      it 'publishes separate RepoToReindexEvent for each node' do
        expect { execute_task }
          .to publish_event(Search::Zoekt::RepoToReindexEvent).with({ zoekt_node_id: node1.id })
          .and publish_event(Search::Zoekt::RepoToReindexEvent).with({ zoekt_node_id: node2.id })
      end
    end

    context 'when there are repositories needing reindexing on a single node' do
      before do
        create(:zoekt_repository, zoekt_index: index1, schema_version: 1, state: :ready)
      end

      it 'publishes a single RepoToReindexEvent for that node' do
        expect { execute_task }.to publish_event(Search::Zoekt::RepoToReindexEvent).with({ zoekt_node_id: node1.id })
      end
    end

    context 'when there are no repositories needing reindexing' do
      before do
        # Create repositories with matching schema versions
        create(:zoekt_repository, zoekt_index: index1, schema_version: 2, state: :ready)
        create(:zoekt_repository, zoekt_index: index2, schema_version: 2, state: :ready)
      end

      it 'does not publish any RepoToReindexEvent' do
        expect { execute_task }.not_to publish_event(Search::Zoekt::RepoToReindexEvent)
      end
    end

    context 'when repositories exist but none need reindexing' do
      before do
        allow(Search::Zoekt::Repository).to receive_message_chain(:schema_version_less_than, :exists?).and_return(false)
      end

      it 'does not publish any RepoToReindexEvent' do
        expect { execute_task }.not_to publish_event(Search::Zoekt::RepoToReindexEvent)
      end
    end
  end

  describe '#indices_to_evict_check' do
    let(:task) { :indices_to_evict_check }
    let_it_be(:_another_index) { create(:zoekt_index) }

    context 'when pending_eviction indices do not exist' do
      it 'does not publishes an IndexToEvictEvent' do
        expect { execute_task }.not_to publish_event(Search::Zoekt::IndexToEvictEvent)
      end
    end

    context 'when pending_eviction indices exist' do
      it 'publishes an IndexToEvictEvent' do
        create(:zoekt_index, state: :pending_eviction)

        expect { execute_task }.to publish_event(Search::Zoekt::IndexToEvictEvent).with({})
      end
    end
  end

  describe '#index_should_be_marked_as_pending_eviction_check' do
    let(:task) { :index_should_be_marked_as_pending_eviction_check }

    context 'when no indices are returned from the pending_eviction scope' do
      it 'does not publish an IndexMarkPendingEvictionEvent' do
        allow(Search::Zoekt::Index).to receive_message_chain(:should_be_pending_eviction, :exists?).and_return(false)

        expect { execute_task }.not_to publish_event(Search::Zoekt::IndexMarkPendingEvictionEvent)
      end
    end

    context 'when indices are returned from the pending eviction scope' do
      it 'publishes an IndexMarkPendingEvictionEvent' do
        allow(Search::Zoekt::Index).to receive_message_chain(:should_be_pending_eviction, :exists?).and_return(true)

        expect { execute_task }.to publish_event(Search::Zoekt::IndexMarkPendingEvictionEvent).with({})
      end
    end
  end

  describe '#node_with_negative_unclaimed_storage_bytes_check' do
    let(:task) { :node_with_negative_unclaimed_storage_bytes_check }
    let_it_be(:negative_node) { create(:zoekt_node, :enough_free_space) }
    let_it_be(:_negative_index) do
      create(:zoekt_index, reserved_storage_bytes: negative_node.total_bytes * 2, node: negative_node)
    end

    let_it_be(:positive_node) { create(:zoekt_node, :enough_free_space) }
    let_it_be(:_positive_index) { create(:zoekt_index, node: positive_node) }

    it 'publishes a NodeWithNegativeUnclaimedStorageEvent for required nodes' do
      expected = { node_ids: [negative_node].map(&:id) }
      expect { execute_task }.to publish_event(Search::Zoekt::NodeWithNegativeUnclaimedStorageEvent).with(expected)
    end
  end

  describe '#force_update_overprovisioned_index' do
    let(:task) { :force_update_overprovisioned_index }

    context 'when with_latest_used_storage_bytes_updated_at indices do not exist' do
      let_it_be(:index) { create(:zoekt_index, :stale_used_storage_bytes_updated_at, :overprovisioned) }

      it 'does not publishes an ForceUpdateOverprovisionedIndexEvent' do
        expect { execute_task }.not_to publish_event(Search::Zoekt::ForceUpdateOverprovisionedIndexEvent)
      end
    end

    context 'when with_latest_used_storage_bytes_updated_at indices exists but they are not overprovisioned' do
      let_it_be(:index) { create(:zoekt_index, :latest_used_storage_bytes, :ready) }

      it 'does not publishes an ForceUpdateOverprovisionedIndexEvent' do
        expect { execute_task }.not_to publish_event(Search::Zoekt::ForceUpdateOverprovisionedIndexEvent)
      end
    end

    context 'when with_latest_used_storage_bytes_updated_at indices exists but they are not ready' do
      let_it_be(:index) { create(:zoekt_index, :latest_used_storage_bytes, :overprovisioned) }

      it 'does not publishes an ForceUpdateOverprovisionedIndexEvent' do
        expect { execute_task }.not_to publish_event(Search::Zoekt::ForceUpdateOverprovisionedIndexEvent)
      end
    end

    context 'when with_latest_used_storage_bytes_updated_at indices exists and they are overprovisioned and ready' do
      let_it_be(:index) { create(:zoekt_index, :latest_used_storage_bytes, :overprovisioned, :ready) }

      it 'publishes an ForceUpdateOverprovisionedIndexEvent' do
        expect { execute_task }.to publish_event(Search::Zoekt::ForceUpdateOverprovisionedIndexEvent)
      end
    end
  end
end
