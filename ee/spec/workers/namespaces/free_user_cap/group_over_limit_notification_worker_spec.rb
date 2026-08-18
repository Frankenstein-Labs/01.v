# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::FreeUserCap::GroupOverLimitNotificationWorker, :with_trial_types, :saas, feature_category: :seat_cost_management, type: :worker do
  describe '#perform', :with_trial_types do
    let_it_be(:owner) { create :owner }
    let_it_be(:group) { create(:group_with_plan, :private, plan: :free_plan, owners: owner) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be_with_reload(:invited_group) { create(:group) }
    let_it_be(:invited_group_with_same_user) { create(:group) }

    let_it_be(:user_with_multiple_members) { create(:user) }
    let_it_be(:project_developer) { project.add_developer(create(:user)).user }
    let_it_be(:group_guest) { group.add_guest(create(:user)).user }
    let_it_be(:project_guest) { project.add_guest(create(:user)).user }

    let_it_be(:member_already_taking_seat) { invited_group_with_same_user.add_developer(user_with_multiple_members) }

    let_it_be(:another_top_level_group) do
      create(:group_with_plan, :private, plan: :free_plan).tap { |g| create_list(:group_member, 4, group: g) }
    end

    let_it_be(:project_with_another_top_level_group) { create(:project, namespace: another_top_level_group) }

    let(:added_member_ids) { [] }
    let(:dashboard_limit_enabled) { true }

    before_all do
      group.add_developer(user_with_multiple_members)
      project.add_developer(user_with_multiple_members)
      invited_group.add_developer(user_with_multiple_members)

      create(:group_group_link, { shared_with_group: invited_group, shared_group: group })
      create(:group_group_link, { shared_with_group: invited_group_with_same_user, shared_group: group })
      create(:project_group_link, project: project, group: invited_group)
      create(:project_group_link, project: project_with_another_top_level_group, group: invited_group)
    end

    before do
      stub_ee_application_setting(dashboard_limit_enabled: dashboard_limit_enabled)
      stub_ee_application_setting(dashboard_limit: 5)
    end

    subject(:perform) { described_class.new.perform(invited_group.id, added_member_ids) }

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [invited_group.id, added_member_ids] }
    end

    context 'when not over limit' do
      it 'does not run notify service' do
        expect(::Namespaces::FreeUserCap::NotifyOverLimitService).not_to receive(:execute)

        perform
      end
    end

    context 'when over limit without members added' do
      before_all do
        invited_group.add_developer(create(:user))
      end

      it 'does not run notify service' do
        expect(::Namespaces::FreeUserCap::NotifyOverLimitService).not_to receive(:execute)

        perform
      end
    end

    context 'when over limit' do
      let_it_be(:new_invited_group_member) { invited_group.add_developer(create(:user)) }
      let_it_be(:another_invited_group_member) { invited_group.add_developer(create(:user)) }

      let(:added_member_ids) do
        [
          new_invited_group_member.id,
          another_invited_group_member.id,
          member_already_taking_seat.id
        ]
      end

      context 'when due to members added from invited group' do
        it 'runs notify service' do
          expect(::Namespaces::FreeUserCap::NotifyOverLimitService).to receive(:execute).with(group)
          expect(::Namespaces::FreeUserCap::NotifyOverLimitService).to receive(:execute).with(another_top_level_group)

          perform
        end
      end

      context 'when the top level group is in the same hierarchy as the invited group' do
        before do
          invited_group.update!(parent: group, visibility_level: Gitlab::VisibilityLevel::PRIVATE)
        end

        it 'does not perform calculation for the group in same hierarchy' do
          expect(::Namespaces::FreeUserCap::Enforcement).not_to receive(:new).with(group)
          expect(::Namespaces::FreeUserCap::Enforcement)
            .to receive(:new).with(another_top_level_group).and_call_original

          perform
        end
      end

      context 'when invited_group does not exist' do
        subject(:perform) { described_class.new.perform(non_existing_record_id, added_member_ids) }

        it 'does not run notify service' do
          expect(::Namespaces::FreeUserCap::NotifyOverLimitService).not_to receive(:execute)

          perform
        end
      end

      context 'when dashboard_limit_enabled is disabled' do
        let(:dashboard_limit_enabled) { false }

        it 'does not run notify service' do
          expect(::Namespaces::FreeUserCap::NotifyOverLimitService).not_to receive(:execute)

          perform
        end
      end
    end

    context 'with multiple top level groups' do
      let_it_be(:new_invited_group_member) { invited_group.add_developer(create(:user)) }
      let_it_be(:another_invited_group_member) { invited_group.add_developer(create(:user)) }
      let_it_be(:under_top_level_group) { create(:group_with_plan, :private, plan: :free_plan) }
      let_it_be(:over_top_level_group) do
        create(:group_with_plan, :private, plan: :free_plan).tap { |g| create_list(:group_member, 3, source: g) }
      end

      let(:added_member_ids) do
        [
          new_invited_group_member.id,
          another_invited_group_member.id,
          member_already_taking_seat.id
        ]
      end

      before_all do
        create(:group_group_link, { shared_with_group: invited_group, shared_group: over_top_level_group })
        create(:group_group_link, { shared_with_group: invited_group, shared_group: under_top_level_group })
      end

      it 'runs notify service' do
        expect(::Namespaces::FreeUserCap::Enforcement).to receive(:new).with(group).and_call_original
        expect(::Namespaces::FreeUserCap::Enforcement).to receive(:new).with(another_top_level_group).and_call_original
        expect(::Namespaces::FreeUserCap::Enforcement).to receive(:new).with(over_top_level_group).and_call_original
        expect(::Namespaces::FreeUserCap::Enforcement).to receive(:new).with(under_top_level_group).and_call_original

        expect(::Namespaces::FreeUserCap::NotifyOverLimitService).to receive(:execute).with(group).and_call_original
        expect(::Namespaces::FreeUserCap::NotifyOverLimitService)
          .to receive(:execute).with(another_top_level_group).and_call_original
        expect(::Namespaces::FreeUserCap::NotifyOverLimitService)
          .to receive(:execute).with(over_top_level_group).and_call_original
        expect(::Namespaces::FreeUserCap::NotifyOverLimitService).not_to receive(:execute).with(under_top_level_group)

        perform
      end

      context 'when top level group limit has been reached' do
        context 'when top level group limit is one' do
          before do
            stub_const("#{described_class}::TOP_LEVEL_GROUPS_LIMIT", 1)
            under_top_level_group.destroy! # so that it does not become the group we check
          end

          it 'runs notify service for one group only' do
            expect(::Namespaces::FreeUserCap::Enforcement).to receive(:new).exactly(1).time.and_call_original
            expect(::Namespaces::FreeUserCap::NotifyOverLimitService).to receive(:execute).exactly(1).time

            perform
          end
        end

        context 'with precedent given to groups with invited groups over projects' do
          before do
            stub_const("#{described_class}::TOP_LEVEL_GROUPS_LIMIT", 3)
          end

          it 'runs the calculation for all except the top level group of the project with an invited group' do
            expect(::Namespaces::FreeUserCap::Enforcement).to receive(:new).with(group).and_call_original
            expect(::Namespaces::FreeUserCap::Enforcement).to receive(:new).with(over_top_level_group).and_call_original
            expect(::Namespaces::FreeUserCap::Enforcement)
              .to receive(:new).with(under_top_level_group).and_call_original

            expect(::Namespaces::FreeUserCap::Enforcement)
              .not_to receive(:new).with(another_top_level_group).and_call_original

            perform
          end
        end
      end

      context 'when invited group is shared multiple times in a hierarchy' do
        let_it_be(:sub_group) { create(:group, :private, parent: group) }

        before_all do
          create(:group_group_link, { shared_with_group: invited_group, shared_group: sub_group })
        end

        it 'de-duplicates the top level group' do
          expect(::Namespaces::FreeUserCap::NotifyOverLimitService)
            .to receive(:execute).once.with(group).and_call_original
          expect(::Namespaces::FreeUserCap::NotifyOverLimitService)
            .to receive(:execute).with(over_top_level_group).and_call_original
          expect(::Namespaces::FreeUserCap::NotifyOverLimitService)
            .to receive(:execute).with(another_top_level_group).and_call_original

          perform
        end
      end
    end
  end
end
