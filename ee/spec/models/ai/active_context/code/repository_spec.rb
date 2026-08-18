# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::Repository, feature_category: :code_suggestions do
  include LooseForeignKeysHelper

  let_it_be(:project) { create(:project) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:enabled_namespace) do
    create(:ai_active_context_code_enabled_namespace, namespace: namespace)
  end

  let(:connection) { enabled_namespace.active_context_connection }
  let(:enabled_namespace_id) { enabled_namespace.id }

  subject(:repository) do
    create(:ai_active_context_code_repository,
      project: project,
      enabled_namespace: enabled_namespace
    )
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:enabled_namespace).class_name('Ai::ActiveContext::Code::EnabledNamespace').optional }
    it { is_expected.to belong_to(:active_context_connection).class_name('Ai::ActiveContext::Connection') }
  end

  describe 'validations' do
    describe 'metadata' do
      it 'is valid for empty hash' do
        repository.metadata = {}
        expect(repository).to be_valid
      end

      it 'is valid when values follow expected types' do
        repository.metadata = {
          initial_indexing_last_queued_item: 'item_ref_123',
          incremental_indexing_last_queued_item: 'item_ref_456',
          last_error: 'Something went wrong'
        }

        expect(repository).to be_valid
      end

      it 'is valid when values are nil' do
        repository.metadata = {
          initial_indexing_last_queued_item: nil,
          incremental_indexing_last_queued_item: nil,
          last_error: nil
        }

        expect(repository).to be_valid
      end

      it 'is invalid for an unexpected key' do
        repository.metadata = { key: 'value' }
        expect(repository).not_to be_valid
      end

      it 'is invalid with wrong type for initial_indexing_last_queued_item' do
        repository.metadata = { initial_indexing_last_queued_item: 123 }
        expect(repository).not_to be_valid
      end

      it 'is invalid with wrong type for incremental_indexing_last_queued_item' do
        repository.metadata = { incremental_indexing_last_queued_item: 456 }
        expect(repository).not_to be_valid
      end

      it 'is invalid with wrong type for last_error' do
        repository.metadata = { last_error: false }
        expect(repository).not_to be_valid
      end
    end

    describe 'connection_id uniqueness' do
      it 'validates uniqueness of connection_id scoped to project_id' do
        create(:ai_active_context_code_repository,
          project: project,
          enabled_namespace: enabled_namespace,
          connection_id: connection.id
        )

        repository2 = build(:ai_active_context_code_repository,
          project: project,
          enabled_namespace: enabled_namespace,
          connection_id: connection.id
        )

        expect(repository2).not_to be_valid
        expect(repository2.errors[:connection_id]).to include('has already been taken')
      end

      it 'allows same connection_id for different project_ids' do
        create(:ai_active_context_code_repository,
          project: project,
          enabled_namespace: enabled_namespace,
          connection_id: connection.id
        )

        repository2 = build(:ai_active_context_code_repository,
          project: create(:project),
          enabled_namespace: enabled_namespace,
          connection_id: connection.id
        )

        expect(repository2).to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.for_connection_and_enabled_namespace' do
      let_it_be(:connection1) { create(:ai_active_context_connection) }
      let_it_be(:connection2) { create(:ai_active_context_connection, :inactive) }
      let_it_be(:enabled_namespace1) do
        create(:ai_active_context_code_enabled_namespace, active_context_connection: connection1)
      end

      let_it_be(:enabled_namespace2) do
        create(:ai_active_context_code_enabled_namespace, active_context_connection: connection2)
      end

      let_it_be(:repository1) do
        create(:ai_active_context_code_repository, enabled_namespace: enabled_namespace1,
          active_context_connection: connection1)
      end

      let_it_be(:repository2) do
        create(:ai_active_context_code_repository, enabled_namespace: enabled_namespace2,
          active_context_connection: connection2)
      end

      let_it_be(:repository3) do
        create(:ai_active_context_code_repository, enabled_namespace: enabled_namespace1,
          active_context_connection: connection1)
      end

      it 'returns repositories for the specified connection and enabled namespace' do
        result = described_class.for_connection_and_enabled_namespace(connection1, enabled_namespace1)

        expect(result).to contain_exactly(repository1, repository3)
      end
    end

    describe '.with_active_connection' do
      let_it_be(:active_connection) { create(:ai_active_context_connection) }
      let_it_be(:inactive_connection) { create(:ai_active_context_connection, :inactive) }
      let_it_be(:repository_with_active_connection) do
        create(:ai_active_context_code_repository, active_context_connection: active_connection)
      end

      let_it_be(:repository_with_inactive_connection) do
        create(:ai_active_context_code_repository, active_context_connection: inactive_connection)
      end

      it 'returns repositories with active connections' do
        result = described_class.with_active_connection

        expect(result).to contain_exactly(repository_with_active_connection)
      end
    end

    describe '.ready_with_active_connection' do
      it 'does not return repositories with inactive connection' do
        expect(described_class.ready_with_active_connection).to be_empty
      end

      context 'when connection is active' do
        before do
          repository.active_context_connection.update!(active: true)
        end

        it 'returns repositories with active connection' do
          expect(described_class.ready_with_active_connection).to be_empty
        end

        context 'when connection is active and repository is ready' do
          before do
            repository.update!(state: :ready)
          end

          it 'returns repositories with active connection' do
            expect(described_class.ready_with_active_connection).to contain_exactly(repository)
          end
        end
      end
    end

    describe '.not_in_delete_states' do
      let_it_be(:pending_repository) { create(:ai_active_context_code_repository, state: :pending) }
      let_it_be(:ready_repository) { create(:ai_active_context_code_repository, state: :ready) }
      let_it_be(:pending_deletion_repository) do
        create(:ai_active_context_code_repository, state: :pending_deletion)
      end

      let_it_be(:deleted_repository) { create(:ai_active_context_code_repository, state: :deleted) }

      it 'excludes repositories in pending_deletion or deleted states' do
        result = described_class.not_in_delete_states

        expect(result).to contain_exactly(pending_repository, ready_repository)
      end
    end

    describe '.no_recent_activity' do
      let_it_be(:before_cutoff) { (described_class::LAST_ACTIVITY_CUTOFF + 1.day).ago }
      let_it_be(:after_cutoff) { (described_class::LAST_ACTIVITY_CUTOFF - 1.day).ago }

      let_it_be(:old_repository) do
        create(:ai_active_context_code_repository, last_queried_at: before_cutoff)
      end

      let_it_be(:recent_repository) do
        create(:ai_active_context_code_repository, last_queried_at: after_cutoff)
      end

      let_it_be(:never_queried_old_repository) do
        create(:ai_active_context_code_repository, last_queried_at: nil, created_at: before_cutoff)
      end

      let_it_be(:never_queried_recent_repository) do
        create(:ai_active_context_code_repository, last_queried_at: nil, created_at: after_cutoff)
      end

      it 'returns repositories queried before the cutoff date' do
        result = described_class.no_recent_activity

        expect(result).to contain_exactly(old_repository, never_queried_old_repository)
      end

      it 'returns repositories never queried but created before the cutoff date' do
        result = described_class.no_recent_activity

        expect(result).to include(never_queried_old_repository)
      end

      it 'excludes repositories never queried and created after the cutoff date' do
        result = described_class.no_recent_activity

        expect(result).not_to include(never_queried_recent_repository)
      end

      it 'excludes repositories queried after the cutoff date' do
        result = described_class.no_recent_activity

        expect(result).not_to include(recent_repository)
      end
    end

    describe '.duo_features_disabled' do
      let_it_be(:project_with_duo_enabled) { create(:project) }
      let_it_be(:project_with_duo_disabled) { create(:project) }

      let_it_be(:repository_duo_enabled) do
        create(:ai_active_context_code_repository, project: project_with_duo_enabled)
      end

      let_it_be(:repository_duo_disabled) do
        create(:ai_active_context_code_repository, project: project_with_duo_disabled)
      end

      before do
        project_with_duo_enabled.project_setting.update!(duo_features_enabled: true)
        project_with_duo_disabled.project_setting.update!(duo_features_enabled: false)
      end

      it 'returns repositories with duo_features_enabled disabled' do
        result = described_class.duo_features_disabled

        expect(result).to contain_exactly(repository_duo_disabled)
      end

      context 'when duo_features_enabled is set on the namespace level' do
        let_it_be(:group_with_duo_disabled, freeze: false) { create(:group) }
        let_it_be(:group_with_duo_enabled, freeze: false) { create(:group) }
        let_it_be(:project_in_disabled_group) { create(:project, namespace: group_with_duo_disabled) }
        let_it_be(:project_in_enabled_group) { create(:project, namespace: group_with_duo_enabled) }

        let_it_be(:repository_namespace_disabled) do
          create(:ai_active_context_code_repository, project: project_in_disabled_group)
        end

        let_it_be(:repository_namespace_enabled) do
          create(:ai_active_context_code_repository, project: project_in_enabled_group)
        end

        before do
          project_in_disabled_group.project_setting.update!(duo_features_enabled: false)
          project_in_enabled_group.project_setting.update!(duo_features_enabled: false)
          group_with_duo_disabled.namespace_settings.update!(duo_features_enabled: false)
          group_with_duo_enabled.namespace_settings.update!(duo_features_enabled: true)
        end

        it 'includes repositories with namespace-level duo_features_enabled disabled' do
          result = described_class.duo_features_disabled

          expect(result).to include(repository_namespace_disabled)
        end

        it 'excludes repositories with namespace-level duo_features_enabled enabled' do
          result = described_class.duo_features_disabled

          expect(result).not_to include(repository_namespace_enabled)
        end
      end
    end

    describe '.without_enabled_namespace' do
      let_it_be(:active_connection) { create(:ai_active_context_connection) }
      let_it_be(:enabled_namespace) do
        create(:ai_active_context_code_enabled_namespace, active_context_connection: active_connection)
      end

      let_it_be(:repository_with_namespace) do
        create(:ai_active_context_code_repository,
          enabled_namespace: enabled_namespace,
          active_context_connection: active_connection)
      end

      let_it_be(:repository_with_nil_namespace, freeze: false) do
        create(:ai_active_context_code_repository, active_context_connection: active_connection)
      end

      before do
        repository_with_nil_namespace.update!(enabled_namespace_id: nil)
      end

      it 'returns repositories with nil enabled namespaces' do
        result = described_class.without_enabled_namespace

        expect(result).to contain_exactly(repository_with_nil_namespace)
      end
    end
  end

  describe 'table partitioning' do
    it 'is partitioned by project_id' do
      expect(described_class.partitioning_strategy).to be_a(Gitlab::Database::Partitioning::IntRangeStrategy)
      expect(described_class.partitioning_strategy.partitioning_key).to eq(:project_id)
    end
  end

  describe '.mark_as_pending_deletion_with_reason' do
    let_it_be(:repository1) { create(:ai_active_context_code_repository, state: :ready) }
    let_it_be(:repository2) { create(:ai_active_context_code_repository, state: :pending) }
    let_it_be(:repository3) { create(:ai_active_context_code_repository, state: :ready) }

    it 'updates all repositories in the scope to pending_deletion state' do
      described_class.where(id: [repository1.id, repository2.id]).mark_as_pending_deletion_with_reason('test_reason')

      expect(repository1.reload.state).to eq('pending_deletion')
      expect(repository2.reload.state).to eq('pending_deletion')
      expect(repository3.reload.state).to eq('ready')
    end

    it 'sets the delete_reason in metadata' do
      described_class.where(id: repository1.id).mark_as_pending_deletion_with_reason('stale_repository')

      repository1.reload
      expect(repository1.delete_reason).to eq('stale_repository')
    end

    it 'preserves existing metadata while adding delete_reason' do
      repository1.update!(metadata: { last_error: 'Some error' })

      described_class.where(id: repository1.id).mark_as_pending_deletion_with_reason('duo_disabled')

      repository1.reload
      expect(repository1.delete_reason).to eq('duo_disabled')
      expect(repository1.last_error).to eq('Some error')
    end

    it 'handles nil metadata' do
      repository1.update!(metadata: nil)

      described_class.where(id: repository1.id).mark_as_pending_deletion_with_reason('invalid_namespace')

      repository1.reload
      expect(repository1.delete_reason).to eq('invalid_namespace')
      expect(repository1.state).to eq('pending_deletion')
    end
  end

  describe 'foreign key constraints' do
    describe 'when enabled_namespace is deleted' do
      it_behaves_like 'cleanup by a loose foreign key' do
        let!(:model) { create(:ai_active_context_code_repository) }
        let!(:parent) { model.enabled_namespace }
      end
    end

    describe 'when project is deleted' do
      it_behaves_like 'update by a loose foreign key' do
        let_it_be(:model) { create(:ai_active_context_code_repository) }
        let!(:parent) { model.project }
      end
    end

    describe 'when connection is deleted' do
      it_behaves_like 'cleanup by a loose foreign key' do
        let!(:model) { create(:ai_active_context_code_repository) }
        let!(:parent) { model.active_context_connection }
      end
    end
  end

  describe '#update_last_queried_timestamp' do
    it 'sets the last_queried_at field to the current time', :freeze_time do
      expect { repository.update_last_queried_timestamp }.to change {
        repository.reload.last_queried_at
      }.to(Time.current)
    end
  end
end
