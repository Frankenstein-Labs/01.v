# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::BulkUpdateSchedulerWorker, feature_category: :security_asset_inventories do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project1) { create(:project, namespace: namespace) }
  let_it_be(:project2) { create(:project, namespace: namespace) }
  let_it_be(:subgroup) { create(:group, parent: namespace) }
  let_it_be(:subproject) { create(:project, namespace: subgroup) }
  let_it_be(:root_namespace) { namespace.root_ancestor }

  let_it_be(:category) { create(:security_category, namespace: root_namespace, name: 'Test Category') }
  let_it_be(:attribute1) do
    create(:security_attribute, security_category: category, name: 'Critical', namespace: root_namespace)
  end

  let_it_be(:attribute2) do
    create(:security_attribute, security_category: category, name: 'High', namespace: root_namespace)
  end

  let(:group_ids) { [] }
  let(:project_ids) { [project1.id, project2.id] }
  let(:attribute_ids) { [attribute1.id, attribute2.id] }
  let(:mode) { 'add' }
  let(:user_id) { user.id }

  subject(:worker) { described_class.new }

  describe '#perform' do
    before_all do
      namespace.add_maintainer(user)
    end

    context 'when user exists' do
      let(:operation_id) { 'test_op_id' }

      it 'creates a background operation and schedules BackgroundOperationBulkUpdateWorker' do
        expect(Gitlab::BackgroundOperations::RedisStore).to receive(:create_operation)
          .with(
            operation_type: 'attribute_update',
            user_id: user.id,
            total_items: 2,
            parameters: { attribute_uids: attribute_ids, mode: 'ADD' }
          )
          .and_return(operation_id)

        expect(Security::Attributes::BackgroundOperationBulkUpdateWorker).to receive(:perform_in)
          .with(0.seconds, match_array([project1.id, project2.id]), attribute_ids, mode, user_id, operation_id)

        worker.perform(group_ids, project_ids, attribute_ids, mode, user_id)
      end

      it 'batches projects correctly' do
        stub_const("#{described_class}::BATCH_SIZE", 1)
        allow(Gitlab::BackgroundOperations::RedisStore).to receive(:create_operation).and_return(operation_id)
        allow(Security::Attributes::BackgroundOperationBulkUpdateWorker).to receive(:perform_in)

        worker.perform(group_ids, project_ids, attribute_ids, mode, user_id)

        expect(Security::Attributes::BackgroundOperationBulkUpdateWorker).to have_received(:perform_in).twice
        expect(Security::Attributes::BackgroundOperationBulkUpdateWorker).to have_received(:perform_in)
          .with(anything, [project1.id], attribute_ids, mode, user_id, operation_id).once
        expect(Security::Attributes::BackgroundOperationBulkUpdateWorker).to have_received(:perform_in)
          .with(anything, [project2.id], attribute_ids, mode, user_id, operation_id).once
      end

      context 'with groups in items' do
        let(:group_ids) { [namespace.id] }
        let(:project_ids) { [] }

        it 'expands groups to include all projects' do
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:create_operation).and_return(operation_id)

          expect(Security::Attributes::BackgroundOperationBulkUpdateWorker).to receive(:perform_in)
            .with(0.seconds, match_array([project1.id, project2.id,
              subproject.id]), attribute_ids, mode, user_id, operation_id)

          worker.perform(group_ids, project_ids, attribute_ids, mode, user_id)
        end
      end

      context 'with mixed groups and projects' do
        let(:group_ids) { [namespace.id] }
        let(:project_ids) { [project1.id] }

        it 'expands groups and deduplicates projects' do
          # project1 appears both directly and through group expansion
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:create_operation).and_return(operation_id)

          expect(Security::Attributes::BackgroundOperationBulkUpdateWorker).to receive(:perform_in)
            .with(0.seconds, match_array([project1.id, project2.id,
              subproject.id]), attribute_ids, mode, user_id, operation_id)

          worker.perform(group_ids, project_ids, attribute_ids, mode, user_id)
        end
      end

      context 'with REMOVE mode' do
        let(:mode) { 'remove' }

        it 'passes correct mode to batch workers' do
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:create_operation).and_return(operation_id)

          expect(Security::Attributes::BackgroundOperationBulkUpdateWorker).to receive(:perform_in)
            .with(0.seconds, match_array([project1.id, project2.id]), attribute_ids, mode, user_id,
              operation_id)

          worker.perform(group_ids, project_ids, attribute_ids, mode, user_id)
        end
      end

      context 'with REPLACE mode' do
        let(:mode) { 'replace' }

        it 'passes correct mode to batch workers' do
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:create_operation).and_return(operation_id)

          expect(Security::Attributes::BackgroundOperationBulkUpdateWorker).to receive(:perform_in)
            .with(0.seconds, match_array([project1.id, project2.id]), attribute_ids, mode, user_id,
              operation_id)

          worker.perform(group_ids, project_ids, attribute_ids, mode, user_id)
        end
      end

      context 'when no accessible projects found' do
        let_it_be(:inaccessible_project) { create(:project) }
        let(:group_ids) { [] }
        let(:project_ids) { [inaccessible_project.id] }

        it 'does not schedule any workers' do
          expect(Security::Attributes::BackgroundOperationBulkUpdateWorker).not_to receive(:perform_in)

          worker.perform(group_ids, project_ids, attribute_ids, mode, user_id)
        end
      end

      context 'with non-existent items' do
        let(:group_ids) { [] }
        let(:project_ids) { [non_existing_record_id] }

        it 'handles non-existent items gracefully' do
          expect(Security::Attributes::BackgroundOperationBulkUpdateWorker).not_to receive(:perform_in)

          worker.perform(group_ids, project_ids, attribute_ids, mode, user_id)
        end
      end

      context 'with mixed valid and invalid items' do
        let(:group_ids) { [] }
        let(:project_ids) { [project1.id, non_existing_record_id] }

        it 'processes only valid items' do
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:create_operation).and_return(operation_id)

          expect(Security::Attributes::BackgroundOperationBulkUpdateWorker).to receive(:perform_in)
            .with(0.seconds, [project1.id], attribute_ids, mode, user_id, operation_id)

          worker.perform(group_ids, project_ids, attribute_ids, mode, user_id)
        end
      end

      context 'when user can read some but not all items' do
        let_it_be(:other_namespace) { create(:group) }
        let_it_be(:other_project) { create(:project, namespace: other_namespace) }
        let(:group_ids) { [] }
        let(:project_ids) { [project1.id, other_project.id] }

        it 'processes only accessible items' do
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:create_operation).and_return(operation_id)

          expect(Security::Attributes::BackgroundOperationBulkUpdateWorker).to receive(:perform_in)
            .with(0.seconds, [project1.id], attribute_ids, mode, user_id, operation_id)

          worker.perform(group_ids, project_ids, attribute_ids, mode, user_id)
        end
      end

      context 'with large number of projects requiring multiple batches' do
        let(:projects) { create_list(:project, 5, namespace: namespace) }
        let(:group_ids) { [] }
        let(:project_ids) { projects.map(&:id) }

        before do
          stub_const("#{described_class}::BATCH_SIZE", 2)
        end

        it 'creates multiple worker jobs with delays' do
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:create_operation).and_return(operation_id)

          expect(Security::Attributes::BackgroundOperationBulkUpdateWorker).to receive(:perform_in)
            .with(0, anything, attribute_ids, mode, user_id, operation_id)
          expect(Security::Attributes::BackgroundOperationBulkUpdateWorker).to receive(:perform_in)
            .with(1.second, anything, attribute_ids, mode, user_id, operation_id)
          expect(Security::Attributes::BackgroundOperationBulkUpdateWorker).to receive(:perform_in)
            .with(2.seconds, anything, attribute_ids, mode, user_id, operation_id)

          worker.perform(group_ids, project_ids, attribute_ids, mode, user_id)
        end
      end

      context 'when security_bulk_operations_notifications feature flag is disabled' do
        before do
          stub_feature_flags(security_bulk_operations_notifications: false)
        end

        it 'schedules the legacy BulkUpdateWorker instead' do
          expect(Security::Attributes::BulkUpdateWorker).to receive(:perform_in)
            .with(0.seconds, match_array([project1.id, project2.id]), attribute_ids, mode, user_id)

          worker.perform(group_ids, project_ids, attribute_ids, mode, user_id)
        end

        it 'does not create a background operation' do
          expect(Gitlab::BackgroundOperations::RedisStore).not_to receive(:create_operation)

          worker.perform(group_ids, project_ids, attribute_ids, mode, user_id)
        end

        context 'with multiple batches' do
          let(:projects) { create_list(:project, 3, namespace: namespace) }
          let(:project_ids) { projects.map(&:id) }

          before do
            stub_const("#{described_class}::BATCH_SIZE", 2)
          end

          it 'schedules multiple BulkUpdateWorker jobs with delays' do
            expect(Security::Attributes::BulkUpdateWorker).to receive(:perform_in)
              .with(0, anything, attribute_ids, mode, user_id)
            expect(Security::Attributes::BulkUpdateWorker).to receive(:perform_in)
              .with(1.second, anything, attribute_ids, mode, user_id)

            worker.perform(group_ids, project_ids, attribute_ids, mode, user_id)
          end
        end
      end
    end

    context 'when user does not exist' do
      let(:user_id) { non_existing_record_id }

      it 'returns early without processing' do
        expect(Security::Attributes::BackgroundOperationBulkUpdateWorker).not_to receive(:perform_in)

        worker.perform(group_ids, project_ids, attribute_ids, mode, user_id)
      end
    end
  end
end
