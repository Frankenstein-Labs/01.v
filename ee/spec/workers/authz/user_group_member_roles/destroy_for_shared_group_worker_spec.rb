# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserGroupMemberRoles::DestroyForSharedGroupWorker, feature_category: :permissions do
  let_it_be(:shared_group) { create(:group) }
  let_it_be(:shared_with_group) { create(:group) }

  let(:job_args) { [shared_group.id, shared_with_group.id] }
  let(:worker) { described_class.new }

  it_behaves_like 'an idempotent worker'

  describe '#perform' do
    subject(:perform) { worker.perform(*job_args) }

    it 'executes Authz::UserGroupMemberRole::DestroyForSharedGroupService' do
      expect_next_instance_of(Authz::UserGroupMemberRoles::DestroyForSharedGroupService, shared_group,
        shared_with_group) do |s|
        expect(s).to receive(:execute)
      end

      perform
    end

    context 'when shared_group does not exist' do
      let(:job_args) { [non_existing_record_id, shared_with_group.id] }

      it 'does not call the service' do
        expect(Authz::UserGroupMemberRoles::DestroyForSharedGroupService).not_to receive(:new)

        perform
      end
    end

    context 'when group does not exist' do
      let(:job_args) { [shared_group.id, non_existing_record_id] }

      it 'does not call the service' do
        expect(Authz::UserGroupMemberRoles::DestroyForSharedGroupService).not_to receive(:new)

        perform
      end
    end
  end
end
