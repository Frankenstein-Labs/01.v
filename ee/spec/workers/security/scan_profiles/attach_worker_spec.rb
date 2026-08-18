# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::AttachWorker, feature_category: :security_testing_configuration do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:scan_profile) do
    create(:security_scan_profile, namespace: group, scan_type: :secret_detection)
  end

  let(:group_id) { group.id }
  let(:scan_profile_id) { scan_profile.id }
  let(:current_user_id) { user.id }
  let(:extra_args) { [] }

  subject(:worker) { described_class.new }

  describe '#perform' do
    subject(:perform_worker) { worker.perform(group_id, scan_profile_id, current_user_id, *extra_args) }

    before do
      allow(Security::ScanProfiles::AttachService).to receive(:execute).and_return({ status: :success })
    end

    it 'delegates to the AttachService with default parameters' do
      perform_worker

      expect(Security::ScanProfiles::AttachService)
        .to have_received(:execute).with(group, scan_profile, current_user: user, traverse_hierarchy: true,
          operation_id: nil)
    end

    context 'with custom `traverse_hierarchy` parameter' do
      let(:extra_args) { [nil, false] }

      it 'delegates to the AttachService with custom parameters' do
        perform_worker

        expect(Security::ScanProfiles::AttachService)
          .to have_received(:execute).with(group, scan_profile, current_user: user, traverse_hierarchy: false,
            operation_id: nil)
      end
    end

    context 'when group does not exist' do
      let(:group_id) { non_existing_record_id }

      it 'exits gracefully without raising an error' do
        expect { perform_worker }.not_to raise_error
      end

      it 'does not call the service' do
        perform_worker

        expect(Security::ScanProfiles::AttachService).not_to have_received(:execute)
      end
    end

    context 'when scan profile does not exist' do
      let(:scan_profile_id) { non_existing_record_id }

      it 'exits gracefully without raising an error' do
        expect { perform_worker }.not_to raise_error
      end

      it 'does not call the service' do
        perform_worker

        expect(Security::ScanProfiles::AttachService).not_to have_received(:execute)
      end
    end

    context 'when current user does not exist' do
      let(:current_user_id) { non_existing_record_id }

      it 'exits gracefully without raising an error' do
        expect { perform_worker }.not_to raise_error
      end

      it 'does not call the service' do
        perform_worker

        expect(Security::ScanProfiles::AttachService).not_to have_received(:execute)
      end
    end

    context 'with operation tracking' do
      let_it_be(:project) { create(:project, group: group) }
      let(:extra_args) { ['op_id', true] }

      it 'passes operation_id to the service' do
        operation = Gitlab::BackgroundOperations::RedisStore::Operation.new(
          id: 'op_id',
          operation_type: 'profile_attach',
          user_id: user.id,
          total_items: 1,
          successful_items: 0,
          failed_items: 0
        )
        allow(Gitlab::BackgroundOperations::RedisStore).to receive(:get_operation).with('op_id').and_return(operation)
        allow(Gitlab::BackgroundOperations::RedisStore).to receive(:increment_successful)
        allow(Gitlab::BackgroundOperations::RedisStore).to receive(:delete_operation)

        perform_worker

        expect(Security::ScanProfiles::AttachService)
          .to have_received(:execute).with(group, scan_profile, current_user: user, traverse_hierarchy: true,
            operation_id: 'op_id')
      end

      context 'when service succeeds' do
        before do
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:get_operation)
            .with('op_id')
            .and_return(Gitlab::BackgroundOperations::RedisStore::Operation.new(
              id: 'op_id',
              operation_type: 'profile_attach',
              user_id: user.id,
              total_items: 1,
              successful_items: 0,
              failed_items: 0
            ))
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:increment_successful)
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:delete_operation)
        end

        it 'increments successful counter' do
          expect(Gitlab::BackgroundOperations::RedisStore).to receive(:increment_successful).with('op_id', 1)

          perform_worker
        end

        it 'does not send failure notification' do
          expect(Security::BackgroundOperationMailer).not_to receive(:failure_notification)

          perform_worker
        end
      end

      context 'when service fails' do
        before do
          allow(Security::ScanProfiles::AttachService).to receive(:execute)
            .and_return({ status: :error, message: 'Scan profile does not belong to group hierarchy' })
        end

        it 'records failure and sends notification' do
          operation = Gitlab::BackgroundOperations::RedisStore::Operation.new(
            id: 'op_id',
            operation_type: 'profile_attach',
            user_id: user.id,
            total_items: 1,
            successful_items: 0,
            failed_items: 1
          )
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:get_operation)
            .with('op_id')
            .and_return(operation)
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:get_failed_items).and_return([])
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:delete_operation)

          expect(Gitlab::BackgroundOperations::RedisStore).to receive(:add_failed_item)
            .with('op_id',
              entity_id: group.id,
              entity_type: 'Group',
              entity_name: group.name,
              entity_full_path: group.full_path,
              error_message: 'Scan profile does not belong to group hierarchy')
          expect(Security::BackgroundOperationMailer).to receive_message_chain(:failure_notification, :deliver_later)

          perform_worker
        end
      end

      context 'with operation_id passed (retry scenario)' do
        let(:extra_args) { ['existing_op_id', false] }

        before do
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:get_operation)
            .with('existing_op_id')
            .and_return(Gitlab::BackgroundOperations::RedisStore::Operation.new(
              id: 'existing_op_id',
              operation_type: 'profile_attach',
              user_id: user.id,
              total_items: 10,
              successful_items: 5,
              failed_items: 0
            ))
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:increment_successful)
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:delete_operation)
        end

        it 'uses the existing operation_id' do
          perform_worker

          expect(Security::ScanProfiles::AttachService)
            .to have_received(:execute).with(group, scan_profile, current_user: user, traverse_hierarchy: false,
              operation_id: 'existing_op_id')
        end
      end

      context 'when operation does not exist (already finalized)' do
        let(:extra_args) { ['deleted_op_id', true] }

        before do
          allow(Gitlab::BackgroundOperations::RedisStore).to receive(:get_operation)
            .with('deleted_op_id')
            .and_return(nil)
        end

        it 'exits early without calling the service' do
          perform_worker

          expect(Security::ScanProfiles::AttachService).not_to have_received(:execute)
        end
      end
    end
  end
end
