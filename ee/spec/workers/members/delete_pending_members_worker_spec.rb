# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::DeletePendingMembersWorker, feature_category: :seat_cost_management do
  let_it_be_with_refind(:group) { create(:group) }
  let_it_be_with_refind(:subgroup) { create(:group, parent: group) }
  let_it_be_with_refind(:project) { create(:project, group: group) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:user) { create(:user) }

  before_all do
    group.add_owner(owner)
  end

  subject(:worker) { described_class.new }

  describe '#perform' do
    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [group.id, owner.id] }
    end

    it 'removes pending group memberships' do
      create(:group_member, :awaiting, group: group, user: user)

      worker.perform(group.id, owner.id)

      expect(group.reload.members.map(&:user_id)).to eq([owner.id])
    end

    it 'removes pending project memberships' do
      create(:project_member, :awaiting, project: project, user: user)

      worker.perform(group.id, owner.id)

      expect(project.reload.members.map(&:user_id)).to be_empty
    end

    it 'does not remove active memberships' do
      member = create(:group_member, group: group, user: user)

      worker.perform(group.id, owner.id)

      expect(group.reload.members.map(&:user_id)).to contain_exactly(owner.id, member.user_id)
    end

    it 'removes multiple pending memberships for the same user' do
      create(:group_member, :awaiting, group: group, user: user)
      create(:group_member, :awaiting, group: subgroup, user: user)

      worker.perform(group.id, owner.id)

      expect(group.reload.members.map(&:user_id)).to eq([owner.id])
      expect(subgroup.reload.members.map(&:user_id)).to be_empty
    end

    it 'does not remove active memberships in subgroups' do
      create(:group_member, :awaiting, group: group, user: user)
      create(:group_member, group: subgroup, user: user)

      worker.perform(group.id, owner.id)

      expect(group.reload.members.map(&:user_id)).to eq([owner.id])
      expect(subgroup.reload.members.map(&:user_id)).to eq([user.id])
    end

    it 'removes invitations' do
      create(:group_member, :invited, group: group)

      worker.perform(group.id, owner.id)

      expect(group.reload.members.map(&:user_id)).to eq([owner.id])
    end

    it 'removes memberships higher up the hierarchy if given a subgroup' do
      create(:group_member, :awaiting, group: group, user: user)

      worker.perform(subgroup.id, owner.id)

      expect(group.reload.members.map(&:user_id)).to eq([owner.id])
    end

    it 'does nothing if the group is not found' do
      create(:group_member, :awaiting, group: subgroup, user: user)

      worker.perform(non_existing_record_id, owner.id)

      expect(subgroup.reload.members.map(&:user_id)).to eq([user.id])
    end

    it 'does nothing if the user initiating the deletion is not found' do
      create(:group_member, :awaiting, group: subgroup, user: user)

      worker.perform(group.id, non_existing_record_id)

      expect(subgroup.reload.members.map(&:user_id)).to eq([user.id])
    end

    it 'requires authorization' do
      other_user = create(:user)
      create(:group_member, :awaiting, group: group, user: user)

      worker.perform(group.id, other_user.id)

      expect(group.reload.members.map(&:user_id)).to contain_exactly(owner.id, user.id)
    end

    it 'stops and schedules itself to run again when the job runs for too long' do
      allow_next_instance_of(::Gitlab::Metrics::RuntimeLimiter) do |limiter|
        allow(limiter).to receive(:over_time?).and_return(true)
      end
      create(:group_member, :awaiting, group: group, user: user)
      create(:group_member, :awaiting, group: group)

      expect(described_class).to receive(:perform_in).with(2.minutes, group.id, owner.id)

      worker.perform(group.id, owner.id)

      expect(group.reload.members.count).to eq(2)
    end
  end
end
