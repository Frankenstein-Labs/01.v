# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserGroupMemberRoles::UpdateForSharedGroupWorker, feature_category: :permissions do
  let_it_be(:link) { create(:group_group_link) }

  let(:job_args) { [link.id] }
  let(:worker) { described_class.new }

  it_behaves_like 'an idempotent worker'

  describe '#perform' do
    subject(:perform) { worker.perform(job_args) }

    it 'executes Authz::UserGroupMemberRoles::UpdateForSharedGroupService' do
      expect_next_instance_of(Authz::UserGroupMemberRoles::UpdateForSharedGroupService, link) do |s|
        expect(s).to receive(:execute)
      end

      perform
    end

    context 'when group_group_link does not exist' do
      let(:job_args) { [non_existing_record_id] }

      it 'does not call the service' do
        expect(Authz::UserGroupMemberRoles::UpdateForSharedGroupService).not_to receive(:new)

        perform
      end
    end
  end
end
