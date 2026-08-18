# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::BackgroundOperationBulkUpdateWorker, feature_category: :security_asset_inventories do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project1) { create(:project, namespace: namespace) }
  let_it_be(:project2) { create(:project, namespace: namespace) }
  let_it_be(:root_namespace) { namespace.root_ancestor }

  let_it_be(:category) { create(:security_category, namespace: root_namespace, name: 'Test Category') }
  let_it_be(:attribute1) do
    create(:security_attribute, security_category: category, name: 'Critical', namespace: root_namespace)
  end

  let_it_be(:attribute2) do
    create(:security_attribute, security_category: category, name: 'High', namespace: root_namespace)
  end

  let(:project_ids) { [project1.id, project2.id] }
  let(:attribute_ids) { [attribute1.id, attribute2.id] }
  let(:mode) { 'ADD' }
  let(:user_id) { user.id }
  let(:operation_id) do
    Gitlab::BackgroundOperations::RedisStore.create_operation(
      operation_type: 'attribute_update',
      user_id: user.id,
      total_items: project_ids.size,
      parameters: { attribute_ids: attribute_ids, mode: mode }
    )
  end

  subject(:worker) { described_class.new }

  after do
    Gitlab::BackgroundOperations::RedisStore.delete_operation(operation_id)
  end

  describe '#perform' do
    before_all do
      namespace.add_maintainer(user)
    end

    context 'when user exists' do
      it 'processes all projects' do
        expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new).twice.and_call_original

        worker.perform(project_ids, attribute_ids, mode, user_id, operation_id)
      end

      it 'calls UpdateProjectAttributesService with correct parameters for ADD mode' do
        expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
          .with(
            project: project1,
            current_user: user,
            params: {
              attributes: {
                add_attribute_ids: attribute_ids,
                remove_attribute_ids: []
              }
            }
          )
          .and_call_original

        expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
          .with(
            project: project2,
            current_user: user,
            params: {
              attributes: {
                add_attribute_ids: attribute_ids,
                remove_attribute_ids: []
              }
            }
          )
          .and_call_original

        worker.perform(project_ids, attribute_ids, mode, user_id, operation_id)
      end

      context 'with REMOVE mode' do
        let(:mode) { 'REMOVE' }

        it 'calls UpdateProjectAttributesService with correct parameters for REMOVE mode' do
          expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
            .with(
              project: project1,
              current_user: user,
              params: {
                attributes: {
                  add_attribute_ids: [],
                  remove_attribute_ids: attribute_ids
                }
              }
            )
            .and_call_original

          expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
            .with(
              project: project2,
              current_user: user,
              params: {
                attributes: {
                  add_attribute_ids: [],
                  remove_attribute_ids: attribute_ids
                }
              }
            )
            .and_call_original

          worker.perform(project_ids, attribute_ids, mode, user_id, operation_id)
        end
      end

      context 'with REPLACE mode' do
        let(:mode) { 'REPLACE' }

        before do
          create(:project_to_security_attribute,
            project: project1,
            security_attribute: attribute1,
            traversal_ids: project1.namespace.traversal_ids)
          create(:project_to_security_attribute,
            project: project2,
            security_attribute: attribute2,
            traversal_ids: project2.namespace.traversal_ids)
        end

        it 'calls UpdateProjectAttributesService with correct parameters for REPLACE mode' do
          expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
            .with(
              project: project1,
              current_user: user,
              params: {
                attributes: {
                  add_attribute_ids: attribute_ids,
                  remove_attribute_ids: [attribute1.id]
                }
              }
            )
            .and_call_original

          expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
            .with(
              project: project2,
              current_user: user,
              params: {
                attributes: {
                  add_attribute_ids: attribute_ids,
                  remove_attribute_ids: [attribute2.id]
                }
              }
            )
            .and_call_original

          worker.perform(project_ids, attribute_ids, mode, user_id, operation_id)
        end

        context 'when project has soft deleted attributes' do
          let(:deleted_attribute) do
            create(:security_attribute, security_category: category, name: 'Deleted',
              namespace: root_namespace, deleted_at: Time.current)
          end

          before do
            create(:project_to_security_attribute,
              project: project1,
              security_attribute: deleted_attribute,
              traversal_ids: project1.namespace.traversal_ids)
          end

          it 'excludes soft deleted attributes from removal list' do
            expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
              .with(
                project: project1,
                current_user: user,
                params: {
                  attributes: {
                    add_attribute_ids: attribute_ids,
                    remove_attribute_ids: [attribute1.id]
                  }
                }
              )
              .and_call_original

            expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
              .with(
                project: project2,
                current_user: user,
                params: {
                  attributes: {
                    add_attribute_ids: attribute_ids,
                    remove_attribute_ids: [attribute2.id]
                  }
                }
              )
              .and_call_original

            worker.perform(project_ids, attribute_ids, mode, user_id, operation_id)
          end
        end
      end

      context 'when project does not exist' do
        let(:project_ids) { [project1.id, non_existing_record_id] }

        it 'processes only existing projects' do
          expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
            .with(hash_including(project: project1))
            .and_call_original

          worker.perform(project_ids, attribute_ids, mode, user_id, operation_id)
        end
      end
    end

    context 'when user does not exist' do
      let(:user_id) { non_existing_record_id }

      it 'returns early without processing' do
        expect(Security::Attributes::UpdateProjectAttributesService).not_to receive(:new)

        worker.perform(project_ids, attribute_ids, mode, user_id, operation_id)
      end
    end

    context 'when operation does not exist' do
      it 'returns early without processing' do
        expect(Security::Attributes::UpdateProjectAttributesService).not_to receive(:new)

        worker.perform(project_ids, attribute_ids, mode, user_id, 'nonexistent_operation')
      end
    end

    context 'with background operation tracking' do
      context 'when service succeeds' do
        before do
          allow_next_instance_of(Security::Attributes::UpdateProjectAttributesService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success)
          end
        end

        it 'increments successful items counter' do
          expect(Gitlab::BackgroundOperations::RedisStore).to receive(:increment_successful)
            .with(operation_id, 1).twice

          worker.perform(project_ids, attribute_ids, mode, user_id, operation_id)
        end
      end

      context 'when service returns error' do
        before do
          allow_next_instance_of(Security::Attributes::UpdateProjectAttributesService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'Service error'))
          end
        end

        it 'records failed items' do
          expect(Gitlab::BackgroundOperations::RedisStore).to receive(:add_failed_item)
            .with(operation_id,
              hash_including(entity_id: project1.id, entity_type: 'Project', error_message: 'Service error'))
          expect(Gitlab::BackgroundOperations::RedisStore).to receive(:add_failed_item)
            .with(operation_id,
              hash_including(entity_id: project2.id, entity_type: 'Project', error_message: 'Service error'))

          worker.perform(project_ids, attribute_ids, mode, user_id, operation_id)
        end
      end

      context 'when service raises an error' do
        before do
          allow_next_instance_of(Security::Attributes::UpdateProjectAttributesService) do |service|
            allow(service).to receive(:execute).and_raise(StandardError, 'Unexpected error')
          end
        end

        it 'records failed items' do
          expect(Gitlab::BackgroundOperations::RedisStore).to receive(:add_failed_item)
            .with(operation_id,
              hash_including(entity_id: project1.id, entity_type: 'Project', error_message: 'Unexpected error'))
          expect(Gitlab::BackgroundOperations::RedisStore).to receive(:add_failed_item)
            .with(operation_id,
              hash_including(entity_id: project2.id, entity_type: 'Project', error_message: 'Unexpected error'))

          worker.perform(project_ids, attribute_ids, mode, user_id, operation_id)
        end

        it 'tracks the exception and continues processing' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception)
            .with(an_instance_of(StandardError), operation_id: operation_id, project_id: project1.id)
          expect(Gitlab::ErrorTracking).to receive(:track_exception)
            .with(an_instance_of(StandardError), operation_id: operation_id, project_id: project2.id)

          expect { worker.perform(project_ids, attribute_ids, mode, user_id, operation_id) }.not_to raise_error
        end
      end
    end

    context 'with operation finalization' do
      let(:project_ids) { [project1.id] }

      context 'when operation completes successfully' do
        let(:operation_id) do
          Gitlab::BackgroundOperations::RedisStore.create_operation(
            operation_type: 'attribute_update',
            user_id: user.id,
            total_items: 1,
            parameters: { attribute_ids: attribute_ids, mode: mode }
          )
        end

        before do
          allow_next_instance_of(Security::Attributes::UpdateProjectAttributesService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success)
          end
        end

        it 'does not send failure notification' do
          expect(Security::BackgroundOperationMailer).not_to receive(:failure_notification)

          worker.perform(project_ids, attribute_ids, mode, user_id, operation_id)
        end

        it 'deletes operation from Redis' do
          worker.perform(project_ids, attribute_ids, mode, user_id, operation_id)

          operation = Gitlab::BackgroundOperations::RedisStore.get_operation(operation_id)
          expect(operation).to be_nil
        end
      end

      context 'when operation completes with failures' do
        let(:operation_id) do
          Gitlab::BackgroundOperations::RedisStore.create_operation(
            operation_type: 'attribute_update',
            user_id: user.id,
            total_items: 1,
            parameters: { attribute_ids: attribute_ids, mode: mode }
          )
        end

        before do
          allow_next_instance_of(Security::Attributes::UpdateProjectAttributesService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'Error'))
          end
        end

        it 'sends failure notification email' do
          expect(Security::BackgroundOperationMailer).to receive_message_chain(:failure_notification, :deliver_later)

          worker.perform(project_ids, attribute_ids, mode, user_id, operation_id)
        end

        it 'deletes operation from Redis after sending notification' do
          allow(Security::BackgroundOperationMailer).to receive_message_chain(:failure_notification, :deliver_later)

          worker.perform(project_ids, attribute_ids, mode, user_id, operation_id)

          operation = Gitlab::BackgroundOperations::RedisStore.get_operation(operation_id)
          expect(operation).to be_nil
        end
      end

      context 'when operation is not yet complete' do
        let(:operation_id) do
          Gitlab::BackgroundOperations::RedisStore.create_operation(
            operation_type: 'attribute_update',
            user_id: user.id,
            total_items: 10, # More items than we're processing
            parameters: { attribute_ids: attribute_ids, mode: mode }
          )
        end

        before do
          allow_next_instance_of(Security::Attributes::UpdateProjectAttributesService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success)
          end
        end

        it 'does not send notification' do
          expect(Security::BackgroundOperationMailer).not_to receive(:failure_notification)

          worker.perform(project_ids, attribute_ids, mode, user_id, operation_id)
        end

        it 'does not delete operation from Redis' do
          worker.perform(project_ids, attribute_ids, mode, user_id, operation_id)

          operation = Gitlab::BackgroundOperations::RedisStore.get_operation(operation_id)
          expect(operation).not_to be_nil
        end
      end

      context 'when operation is deleted during finalization' do
        let(:operation_id) do
          Gitlab::BackgroundOperations::RedisStore.create_operation(
            operation_type: 'attribute_update',
            user_id: user.id,
            total_items: 1,
            parameters: { attribute_ids: attribute_ids, mode: mode }
          )
        end

        it 'handles missing operation gracefully' do
          allow_next_instance_of(Security::Attributes::UpdateProjectAttributesService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success)
          end

          # Get the real operation before setting up the mock
          real_operation = Gitlab::BackgroundOperations::RedisStore.get_operation(operation_id)

          # Return real operation for operation_exists? check, then nil for finalize_if_complete
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:get_operation)
            .with(operation_id)
            .and_return(real_operation, nil)

          expect(Security::BackgroundOperationMailer).not_to receive(:failure_notification)
          expect { worker.perform(project_ids, attribute_ids, mode, user_id, operation_id) }.not_to raise_error
        end
      end
    end
  end
end
