# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::MarkRepositoryAsPendingDeletionEventWorker, feature_category: :global_search do
  let(:event_class) { Ai::ActiveContext::Code::MarkRepositoryAsPendingDeletionEvent }
  let(:event) { event_class.new(data: {}) }

  subject(:execute) { consume_event(subscriber: described_class, event: event) }

  before do
    allow(Ai::ActiveContext::Code::Repository).to receive(:with_each_partition)
      .and_yield(Ai::ActiveContext::Code::Repository)
  end

  it_behaves_like 'subscribes to event'

  describe '#handle_event', :clean_gitlab_redis_shared_state do
    context 'when indexing is disabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(false)
      end

      it 'does not process' do
        expect(Ai::ActiveContext::Code::Repository).not_to receive(:with_each_partition)

        expect(execute).to eq([{}])
      end
    end

    context 'when indexing is enabled' do
      let_it_be(:connection) { create(:ai_active_context_connection, active: true) }
      let_it_be(:enabled_namespace) do
        create(:ai_active_context_code_enabled_namespace, :ready, active_context_connection: connection)
      end

      let_it_be(:old_repository) do
        create(:ai_active_context_code_repository,
          enabled_namespace: enabled_namespace,
          state: :ready,
          connection_id: connection.id,
          last_queried_at: 4.months.ago
        )
      end

      let_it_be(:recent_repository) do
        create(:ai_active_context_code_repository,
          enabled_namespace: enabled_namespace,
          state: :ready,
          connection_id: connection.id,
          last_queried_at: 1.day.ago
        )
      end

      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(true)
      end

      context 'with repositories without enabled namespace' do
        let_it_be(:repository_without_namespace, freeze: false) do
          create(:ai_active_context_code_repository,
            state: :ready,
            connection_id: connection.id
          )
        end

        before do
          repository_without_namespace.update_column(:enabled_namespace_id, nil)
        end

        it 'marks repositories without enabled namespace as pending_deletion' do
          execute

          expect(repository_without_namespace.reload.state).to eq('pending_deletion')
          expect(repository_without_namespace.delete_reason).to eq('without_enabled_namespace')
        end
      end

      context 'with repositories with disabled duo features' do
        let_it_be(:project_with_duo_disabled) { create(:project) }
        let_it_be(:repository_duo_disabled) do
          create(:ai_active_context_code_repository,
            enabled_namespace: enabled_namespace,
            state: :ready,
            connection_id: connection.id,
            project: project_with_duo_disabled
          )
        end

        before do
          project_with_duo_disabled.project_setting.update!(duo_features_enabled: false)
        end

        it 'marks repositories with disabled duo features as pending_deletion' do
          execute

          expect(repository_duo_disabled.reload.state).to eq('pending_deletion')
          expect(repository_duo_disabled.delete_reason).to eq('duo_features_disabled')
        end
      end

      it 'marks stale repositories as pending_deletion' do
        execute

        expect(old_repository.reload.state).to eq('pending_deletion')
        expect(old_repository.delete_reason).to eq('no_recent_activity')
      end

      it 'does not mark recent repositories as pending_deletion' do
        execute

        expect(recent_repository.reload.state).to eq('ready')
      end

      context 'when batch size limit is reached' do
        let_it_be(:repository_without_namespace, freeze: false) do
          create(:ai_active_context_code_repository,
            state: :ready,
            connection_id: connection.id
          )
        end

        let_it_be(:project_with_duo_disabled) { create(:project) }
        let_it_be(:repository_duo_disabled) do
          create(:ai_active_context_code_repository,
            enabled_namespace: enabled_namespace,
            state: :ready,
            connection_id: connection.id,
            project: project_with_duo_disabled
          )
        end

        before do
          stub_const("#{described_class}::BATCH_SIZE", 2)
          repository_without_namespace.update_column(:enabled_namespace_id, nil)
          project_with_duo_disabled.project_setting.update!(duo_features_enabled: false)
        end

        it 'processes only up to BATCH_SIZE records total' do
          execute

          pending_deletion_count = Ai::ActiveContext::Code::Repository
            .where(state: :pending_deletion)
            .count

          expect(pending_deletion_count).to be <= 2
        end

        it 'prioritizes without_enabled_namespace over other categories' do
          execute

          expect(repository_without_namespace.reload.state).to eq('pending_deletion')
        end

        it 'reemits event when batch limit is reached' do
          additional_no_namespace = create(:ai_active_context_code_repository,
            state: :ready,
            connection_id: connection.id
          )
          additional_no_namespace.update_column(:enabled_namespace_id, nil)

          expect(Gitlab::EventStore).to receive(:publish).once.with(
            an_instance_of(Ai::ActiveContext::Code::MarkRepositoryAsPendingDeletionEvent)
          )

          execute

          pending_deletion_count = Ai::ActiveContext::Code::Repository
            .where(state: :pending_deletion)
            .count

          expect(pending_deletion_count).to eq(2)
        end
      end

      context 'with multiple partitions' do
        before do
          allow(Ai::ActiveContext::Code::Repository).to receive(:with_each_partition)
            .and_yield(Ai::ActiveContext::Code::Repository)
            .and_yield(Ai::ActiveContext::Code::Repository)
        end

        context 'when limit is reached in first partition' do
          before do
            stub_const("#{described_class}::BATCH_SIZE", 1)
          end

          it 'stops processing when limit is reached' do
            execute

            pending_deletion_count = Ai::ActiveContext::Code::Repository
              .where(state: :pending_deletion)
              .count

            expect(pending_deletion_count).to eq(1)
          end
        end
      end
    end
  end

  describe '#relation' do
    let(:worker) { described_class.new }
    let(:partition) { Ai::ActiveContext::Code::Repository }

    context 'when scope_name is :without_enabled_namespace' do
      it 'returns relation with correct scopes applied' do
        relation = worker.send(:relation, partition, :without_enabled_namespace)

        expect(relation.to_sql).to include('"enabled_namespace_id" IS NULL')
        expect(relation.to_sql).to include('active_context_connections')
        expect(relation.to_sql).to include('"state" NOT IN')
      end
    end

    context 'when scope_name is :duo_features_disabled' do
      it 'returns relation with correct scopes applied' do
        relation = worker.send(:relation, partition, :duo_features_disabled)

        expect(relation.to_sql).to include('project_settings')
        expect(relation.to_sql).to include('duo_features_enabled')
        expect(relation.to_sql).to include('active_context_connections')
        expect(relation.to_sql).to include('"state" NOT IN')
      end
    end

    context 'when scope_name is :no_recent_activity' do
      it 'returns relation with correct scopes applied' do
        relation = worker.send(:relation, partition, :no_recent_activity)

        expect(relation.to_sql).to include('last_queried_at')
        expect(relation.to_sql).to include('active_context_connections')
        expect(relation.to_sql).to include('"state" NOT IN')
      end
    end

    context 'when scope_name is unknown' do
      it 'raises ArgumentError' do
        expect do
          worker.send(:relation, partition, :invalid_scope)
        end.to raise_error(ArgumentError, 'Unknown scope: invalid_scope')
      end
    end
  end
end
