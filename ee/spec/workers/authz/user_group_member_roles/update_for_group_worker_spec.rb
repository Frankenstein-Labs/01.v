# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserGroupMemberRoles::UpdateForGroupWorker, feature_category: :permissions do
  let_it_be(:member) { create(:group_member) }

  let(:job_args) { [member.id] }
  let(:worker) { described_class.new }

  it_behaves_like 'an idempotent worker'

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  it 'has an option to reschedule once if deduplicated' do
    expect(described_class.get_deduplication_options).to include(
      { if_deduplicated: :reschedule_once, including_scheduled: true }
    )
  end

  describe '#perform' do
    subject(:perform) { worker.perform(job_args) }

    it 'executes Authz::UserGroupMemberRoles::UpdateForGroupService with the member' do
      expect_next_instance_of(Authz::UserGroupMemberRoles::UpdateForGroupService, member) do |s|
        expect(s).to receive(:execute)
      end

      perform
    end

    context 'when member does not exist' do
      let(:job_args) { [non_existing_record_id] }

      it 'does not call the service' do
        expect(Authz::UserGroupMemberRoles::UpdateForGroupService).not_to receive(:new)

        perform
      end
    end
  end
end
