# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserGroupMemberRoles::DestroyForGroupWorker, feature_category: :permissions do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:job_args) { [user.id, group.id] }
  let(:worker) { described_class.new }

  it_behaves_like 'an idempotent worker'

  describe '#perform' do
    subject(:perform) { worker.perform(*job_args) }

    it 'executes DestroyForGroupService' do
      expect_next_instance_of(Authz::UserGroupMemberRoles::DestroyForGroupService, user, group) do |s|
        expect(s).to receive(:execute)
      end

      perform
    end

    context 'when user does not exist' do
      let(:job_args) { [non_existing_record_id, group.id] }

      it 'does not call the service' do
        expect(Authz::UserGroupMemberRoles::DestroyForGroupService).not_to receive(:new)

        perform
      end
    end

    context 'when group does not exist' do
      let(:job_args) { [user.id, non_existing_record_id] }

      it 'does not call the service' do
        expect(Authz::UserGroupMemberRoles::DestroyForGroupService).not_to receive(:new)

        perform
      end
    end
  end
end
