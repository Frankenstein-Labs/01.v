# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::SchedulingService, feature_category: :global_search do
  describe '#execute' do
    let(:redis_throttle) { class_spy(Gitlab::Utils::RedisThrottle) }
    let(:tasks) { { example_task: { dispatch: { event: TestEvent } } } }
    let(:event_class) do
      Class.new(::Gitlab::EventStore::Event) do
        def schema
          {
            'type' => 'object',
            'properties' => {},
            'additionalProperties' => false
          }
        end
      end
    end

    subject(:execute) { described_class.new(:example_task).execute }

    before do
      stub_const('TestEvent', event_class)
      stub_const("#{described_class}::TASKS", tasks)
      allow(Gitlab::EventStore).to receive(:publish)
      allow(Gitlab::Utils::RedisThrottle).to receive(:execute_every).and_yield
    end

    context 'with valid task' do
      it 'publishes an event to the event store' do
        execute

        expect(Gitlab::EventStore).to have_received(:publish).with(an_instance_of(TestEvent))
      end

      it 'uses RedisThrottle.execute_every with the correct cache key' do
        expected_cache_key = 'ai/active_context/code/scheduling_service:execute_every:-:example_task'

        execute

        expect(Gitlab::Utils::RedisThrottle).to have_received(:execute_every).with(nil, expected_cache_key)
      end
    end

    context 'with periodic task' do
      let(:tasks) { { example_task: { period: 5.minutes, dispatch: { event: TestEvent } } } }

      it 'uses RedisThrottle.execute_every with the correct period and cache key' do
        expected_cache_key = 'ai/active_context/code/scheduling_service:execute_every:300:example_task'

        execute

        expect(Gitlab::Utils::RedisThrottle).to have_received(:execute_every).with(
          5.minutes, expected_cache_key
        )
      end
    end

    context 'with conditional task' do
      context 'when condition is true' do
        let(:tasks) { { example_task: { if: -> { true }, dispatch: { event: TestEvent } } } }

        it 'publishes the event' do
          execute

          expect(Gitlab::EventStore).to have_received(:publish)
        end
      end

      context 'when condition is false' do
        let(:tasks) { { example_task: { if: -> { false }, dispatch: { event: TestEvent } } } }

        it 'does not publish the event' do
          execute

          expect(Gitlab::EventStore).not_to have_received(:publish)
        end
      end
    end

    context 'with execute block' do
      let(:tasks) do
        {
          example_task: {
            execute: -> { true }
          }
        }
      end

      it 'executes the provided block' do
        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:instance_exec).once
        end

        execute
      end
    end

    context 'with invalid task' do
      it 'raises ArgumentError for unknown task' do
        service = described_class.new(:unknown_task)

        expect { service.execute }.to raise_error(ArgumentError, 'Unknown task: :unknown_task')
      end

      context 'without execute or dispatch' do
        let(:tasks) { { example_task: { if: -> { true } } } }

        it 'raises NotImplementedError' do
          message = 'No execute block or dispatch defined for task example_task'
          expect { execute }.to raise_error(NotImplementedError, message)
        end
      end
    end
  end

  describe 'index_repository task' do
    subject(:execute) { described_class.new(:index_repository).execute }

    before do
      allow(Gitlab::Utils::RedisThrottle).to receive(:execute_every).and_yield
    end

    context 'when there are pending repositories with active connections' do
      let_it_be(:active_connection) { create(:ai_active_context_connection, active: true) }
      let_it_be(:enabled_namespace) do
        create(:ai_active_context_code_enabled_namespace, connection_id: active_connection.id)
      end

      let_it_be(:pending_repository) do
        create(:ai_active_context_code_repository,
          state: :pending,
          enabled_namespace: enabled_namespace,
          connection_id: active_connection.id)
      end

      it 'processes pending repositories' do
        expect(Ai::ActiveContext::Code::RepositoryIndexService).to receive(:enqueue_pending_jobs)

        execute
      end
    end

    context 'when there are no pending repositories with active connections' do
      let_it_be(:inactive_connection) { create(:ai_active_context_connection, :inactive) }
      let_it_be(:enabled_namespace) do
        create(:ai_active_context_code_enabled_namespace, connection_id: inactive_connection.id)
      end

      let_it_be(:repository_with_inactive_connection) do
        create(:ai_active_context_code_repository,
          state: :pending,
          enabled_namespace: enabled_namespace,
          connection_id: inactive_connection.id)
      end

      it 'does not process repositories' do
        expect(Ai::ActiveContext::Code::RepositoryIndexService).not_to receive(:enqueue_pending_jobs)

        execute
      end
    end

    context 'when repositories exist but are not in pending state' do
      let_it_be(:active_connection) { create(:ai_active_context_connection, active: true) }
      let_it_be(:enabled_namespace) do
        create(:ai_active_context_code_enabled_namespace, connection_id: active_connection.id)
      end

      let_it_be(:ready_repository) do
        create(:ai_active_context_code_repository,
          state: :ready,
          enabled_namespace: enabled_namespace,
          connection_id: active_connection.id)
      end

      it 'does not process non-pending repositories' do
        expect(Ai::ActiveContext::Code::RepositoryIndexService).not_to receive(:enqueue_pending_jobs)

        execute
      end
    end
  end

  describe '#cache_period' do
    let(:service) { described_class.new(:example_task) }

    context 'when task has a period' do
      before do
        stub_const("#{described_class}::TASKS", { example_task: { period: 5.minutes } })
      end

      it 'returns the period from the task config' do
        expect(service.cache_period).to eq(5.minutes)
      end
    end

    context 'when task has no period' do
      before do
        stub_const("#{described_class}::TASKS", { example_task: {} })
      end

      it 'returns nil' do
        expect(service.cache_period).to be_nil
      end
    end

    context 'when task does not exist' do
      before do
        stub_const("#{described_class}::TASKS", {})
      end

      it 'returns nil' do
        expect(service.cache_period).to be_nil
      end
    end
  end

  describe '#cache_key_for_period' do
    let(:service) { described_class.new(:example_task) }

    it 'generates a correct cache key with nil period' do
      expect(service.send(:cache_key_for_period, nil))
        .to eq('ai/active_context/code/scheduling_service:execute_every:-:example_task')
    end

    it 'generates a correct cache key with a period' do
      expected_cache_key = 'ai/active_context/code/scheduling_service:execute_every:300:example_task'
      expect(service.send(:cache_key_for_period, 5.minutes)).to eq(expected_cache_key)
    end
  end

  describe 'tasks' do
    describe 'process_pending_enabled_namespace' do
      before do
        allow(Gitlab::EventStore).to receive(:publish)
      end

      context 'when there are pending namespaces to process' do
        before do
          allow(Ai::ActiveContext::Code::EnabledNamespace)
            .to receive_message_chain(:pending, :with_active_connection, :exists?).and_return(true)
        end

        it 'publishes ProcessPendingEnabledNamespaceEvent' do
          described_class.new(:process_pending_enabled_namespace).execute

          expect(Gitlab::EventStore).to have_received(:publish)
            .with(an_instance_of(Ai::ActiveContext::Code::ProcessPendingEnabledNamespaceEvent))
        end
      end

      context 'when there are no pending namespaces to process' do
        before do
          allow(Ai::ActiveContext::Code::EnabledNamespace)
            .to receive_message_chain(:pending, :with_active_connection, :exists?).and_return(false)
        end

        it 'does not publish the event' do
          described_class.new(:process_pending_enabled_namespace).execute

          expect(Gitlab::EventStore).not_to have_received(:publish)
        end
      end
    end

    describe 'index_repository' do
      context 'when there are repositories to process' do
        before do
          allow(::Ai::ActiveContext::Code::Repository)
            .to receive_message_chain(:pending, :with_active_connection, :exists?).and_return(true)
        end

        it 'enqueues jobs via RepositoryIndexService' do
          expect(::Ai::ActiveContext::Code::RepositoryIndexService).to receive(:enqueue_pending_jobs)

          described_class.new(:index_repository).execute
        end
      end

      context 'when there are no repositories to process' do
        before do
          allow(::Ai::ActiveContext::Code::Repository)
            .to receive_message_chain(:pending, :with_active_connection, :exists?).and_return(false)
        end

        it 'does not enqueue jobs via RepositoryIndexService' do
          expect(::Ai::ActiveContext::Code::RepositoryIndexService).not_to receive(:enqueue_pending_jobs)

          described_class.new(:index_repository).execute
        end
      end
    end

    describe 'delete_repository' do
      context 'when there are repositories pending deletion with active connections' do
        before do
          allow(::Ai::ActiveContext::Code::Repository)
            .to receive_message_chain(:pending_deletion, :with_active_connection, :exists?).and_return(true)
        end

        it 'enqueues deletion jobs via RepositoryIndexService' do
          expect(::Ai::ActiveContext::Code::RepositoryIndexService).to receive(:enqueue_pending_deletion_jobs)

          described_class.new(:delete_repository).execute
        end
      end

      context 'when there are no repositories pending deletion with active connections' do
        before do
          allow(::Ai::ActiveContext::Code::Repository)
            .to receive_message_chain(:pending_deletion, :with_active_connection, :exists?).and_return(false)
        end

        it 'does not enqueue deletion jobs via RepositoryIndexService' do
          expect(::Ai::ActiveContext::Code::RepositoryIndexService).not_to receive(:enqueue_pending_deletion_jobs)

          described_class.new(:delete_repository).execute
        end
      end
    end
  end
end
