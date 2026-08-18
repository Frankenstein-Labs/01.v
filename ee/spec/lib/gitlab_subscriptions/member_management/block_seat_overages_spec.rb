# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::BlockSeatOverages, feature_category: :seat_cost_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }

  let(:source) { subgroup }

  describe '.block_seat_overages?' do
    subject(:block_seat_overages?) { described_class.block_seat_overages?(source) }

    context 'when on GitLab.com', :saas do
      it 'delegates to root namespace' do
        expect(group).to receive(:block_seat_overages?)

        block_seat_overages?
      end
    end

    context 'when on self-managed' do
      let(:seat_control_block_overages) { 2 }
      let(:seat_control_off) { 0 }

      it 'returns true when seat control is set to block overages' do
        stub_application_setting(seat_control: seat_control_block_overages)

        expect(block_seat_overages?).to be true
      end

      it 'returns false when seat control is disabled' do
        stub_application_setting(seat_control: seat_control_off)

        expect(block_seat_overages?).to be false
      end
    end
  end

  describe '.seats_available_for?' do
    let(:invites) { [user1.id, user2.id] }
    let(:access_level) { Gitlab::Access::DEVELOPER }
    let(:member_role_id) { nil }
    let(:non_billable_member_role) { create(:member_role, :instance, :non_billable) }
    let(:billable_member_role) { create(:member_role, :instance, :billable) }
    let(:user3) { create(:user) }
    let(:user4) { create(:user) }
    let(:non_existing_email) { 'nonexistingemail@email.com' }

    let(:seats_available?) do
      described_class.seats_available_for?(source, invites, access_level, member_role_id)
    end

    context 'when on GitLab.com', :saas do
      let_it_be_with_refind(:group) { create(:group_with_plan, plan: :premium_plan) }

      let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
      let(:total_license_seats) { 1 }

      before do
        allow(License).to receive(:current).and_return(license)
        allow(license).to receive(:seats).and_return(total_license_seats)
      end

      before_all do
        group.gitlab_subscription.update!(seats: 5)
      end

      it 'returns true if there are enough seats for the group, regardless of the license' do
        invites = %w[guy1@example.com guy2@example.com]

        expect(described_class.seats_available_for?(group, invites, ::Gitlab::Access::DEVELOPER, nil)).to be true
      end
    end

    context 'when on self-managed' do
      let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
      let(:total_license_seats) { 0 }

      before do
        allow(License).to receive(:current).and_return(license)
        allow(license).to receive(:seats).and_return(total_license_seats)
      end

      context 'with non-billable members' do
        context 'with service bot users' do
          let(:service_bot) { create(:user, :bot) }
          let(:invites) { [service_bot.id] }

          it 'returns true' do
            expect(seats_available?).to be true
          end
        end

        context 'with minimal access level' do
          let(:access_level) { Gitlab::Access::MINIMAL_ACCESS }

          it 'returns true' do
            expect(seats_available?).to be true
          end
        end

        context 'with guest access level' do
          let(:access_level) { Gitlab::Access::GUEST }

          it 'returns true' do
            expect(seats_available?).to be true
          end
        end

        context 'with non-billable custom role' do
          let(:member_role_id) { non_billable_member_role.id }

          it 'returns true' do
            expect(seats_available?).to be true
          end
        end
      end

      context 'with billable members' do
        before do
          allow(described_class).to receive(:get_billable_user_ids).and_return([user1.id.to_s])
        end

        context 'when invites are existing billable members' do
          context 'with user ids' do
            let(:invites) { [user1.id] }

            it 'returns true' do
              expect(seats_available?).to be true
            end
          end

          context 'with string user ids' do
            let(:invites) { [user1.id.to_s] }

            it 'returns true' do
              expect(seats_available?).to be true
            end
          end

          context 'with existing user emails' do
            let(:invites) { [user1.email] }

            it 'returns true' do
              expect(seats_available?).to be true
            end
          end
        end

        context 'for new billable invites' do
          context 'with enough seats' do
            let(:total_license_seats) { 5 }

            context 'with mix of user id, id as string and emails' do
              let(:invites) { [user2.id, user4.id.to_s, user3.email, non_existing_email] }

              it 'returns true' do
                expect(seats_available?).to be true
              end
            end
          end

          context 'with not enough seats' do
            let(:total_license_seats) { 4 }

            context 'with mix of User id, id as string and emails' do
              let(:invites) { [user2.id, user4.id.to_s, user3.email, non_existing_email] }

              it 'returns false' do
                expect(seats_available?).to be false
              end
            end

            context 'when on premium plan' do
              let(:total_license_seats) { 1 }
              let(:license) { create(:license, plan: License::PREMIUM_PLAN) }
              let(:invites) { [user2.id] }

              context 'with minimal access level' do
                let(:access_level) { Gitlab::Access::MINIMAL_ACCESS }

                it 'returns false' do
                  expect(seats_available?).to be false
                end
              end
            end

            context 'with billable custom roles' do
              let(:total_license_seats) { 1 }
              let(:member_role_id) { billable_member_role.id }
              let(:invites) { [user2.id] }

              it 'returns false' do
                expect(seats_available?).to be false
              end
            end
          end
        end
      end
    end
  end

  describe '.seats_available_for_group?' do
    context 'with a subscription', :saas do
      let_it_be_with_refind(:group) { create(:group_with_plan, plan: :premium_plan) }
      let_it_be(:user) { create(:user) }

      before_all do
        group.gitlab_subscription.update!(seats: 5)
      end

      it 'returns true if there are enough seats' do
        user_ids = %w[1 2 3]

        expect(described_class.seats_available_for_group?(group, user_ids, ::Gitlab::Access::DEVELOPER,
          nil)).to be(true)
      end

      it 'returns false if there are not enough seats' do
        user_ids = %w[1 2 3 4 5 6]

        expect(described_class.seats_available_for_group?(group, user_ids, ::Gitlab::Access::DEVELOPER,
          nil)).to be(false)
      end

      it 'returns true if there are exactly enough seats remaining' do
        user_ids = %w[1 2 3 4 5]

        expect(described_class.seats_available_for_group?(group, user_ids, ::Gitlab::Access::DEVELOPER,
          nil)).to be(true)
      end

      it 'counts members in subgroups as consuming seats' do
        subgroup = create(:group, parent: group)
        subgroup.add_developer(user)
        invites = %w[a@example.com b@example.com c@example.com d@example.com e@example.com]

        expect(described_class.seats_available_for_group?(group, invites, ::Gitlab::Access::DEVELOPER,
          nil)).to be(false)
      end

      it 'considers if users are already consuming a seat' do
        group.gitlab_subscription.update!(seats: 1)
        group.add_developer(user)

        expect(described_class.seats_available_for_group?(group, [user.id.to_s], ::Gitlab::Access::DEVELOPER,
          nil)).to be(true)
      end

      it 'considers if users are already consuming a seat when the seat count is exceeded' do
        group.gitlab_subscription.update!(seats: 1)
        group.add_developer(user)
        group.add_developer(create(:user))

        expect(described_class.seats_available_for_group?(group, [user.id.to_s], ::Gitlab::Access::MAINTAINER,
          nil)).to be(true)
      end

      it 'returns true if passed an empty array' do
        expect(described_class.seats_available_for_group?(group, [], ::Gitlab::Access::DEVELOPER, nil)).to be(true)
      end

      it 'returns true if there are no seats remaining and the passed array is empty' do
        group.gitlab_subscription.update!(seats: 1)
        group.add_maintainer(user)

        expect(described_class.seats_available_for_group?(group, [], ::Gitlab::Access::DEVELOPER, nil)).to be(true)
      end

      it 'accepts an array of integers' do
        user_ids = [1, 2, 3]

        expect(described_class.seats_available_for_group?(group, user_ids, ::Gitlab::Access::DEVELOPER,
          nil)).to be(true)
      end

      it 'returns true when the access level is minimal access even if there are not enough seats' do
        user_ids = %w[1 2 3 4 5 6]

        expect(described_class.seats_available_for_group?(group, user_ids, ::Gitlab::Access::MINIMAL_ACCESS,
          nil)).to be(true)
      end

      it 'returns false when the access level is guest if there are not enough seats' do
        user_ids = %w[1 2 3 4 5 6]

        expect(described_class.seats_available_for_group?(group, user_ids, ::Gitlab::Access::GUEST, nil)).to be(false)
      end
    end

    context 'with an ultimate subscription', :saas do
      let_it_be_with_refind(:group) { create(:group_with_plan, plan: :ultimate_plan) }

      before_all do
        group.gitlab_subscription.update!(seats: 2)
      end

      it 'returns true when the access level is guest even if there are not enough seats' do
        user_ids = %w[1 2 3]

        expect(described_class.seats_available_for_group?(group, user_ids, ::Gitlab::Access::GUEST, nil)).to be(true)
      end

      it 'returns false when there are not enough seats if the custom role is billable' do
        custom_role = create(:member_role, :guest, :remove_project)
        user_ids = %w[1 2 3]

        expect(described_class.seats_available_for_group?(group, user_ids, ::Gitlab::Access::GUEST,
          custom_role.id)).to be(false)
      end

      it 'returns true even if there are not enough seats if the custom role is not billable' do
        custom_role = create(:member_role, :guest, :read_code)
        user_ids = %w[1 2 3]

        expect(described_class.seats_available_for_group?(group, user_ids, ::Gitlab::Access::GUEST,
          custom_role.id)).to be(true)
      end

      it 'returns false when there are not enough seats if the custom role is billable and based on minimal access' do
        custom_role = create(:member_role, :minimal_access, :remove_project)
        user_ids = %w[1 2 3]

        expect(described_class.seats_available_for_group?(group, user_ids, ::Gitlab::Access::MINIMAL_ACCESS,
          custom_role.id)).to be(false)
      end

      it 'assumes the custom role is billable if given an invalid member role id' do
        user_ids = %w[1 2 3]

        expect(described_class.seats_available_for_group?(group, user_ids, ::Gitlab::Access::GUEST, 1)).to be(false)
      end
    end

    context 'with a subscription downgraded to free', :saas do
      let_it_be_with_refind(:group) { create(:group_with_plan, plan: :free_plan) }

      before_all do
        group.gitlab_subscription.update!(seats: 0)
      end

      it 'returns true' do
        user_ids = %w[1 2 3 4 5 6 7 8 9 10 11 12]

        expect(described_class.seats_available_for_group?(group, user_ids, ::Gitlab::Access::DEVELOPER,
          nil)).to be(true)
      end
    end

    context 'without a subscription' do
      it 'returns true' do
        user_ids = %w[1 2 3 4 5 6 7 8 9 10 11 12]

        expect(described_class.seats_available_for_group?(group, user_ids, ::Gitlab::Access::DEVELOPER,
          nil)).to be(true)
      end
    end
  end

  describe '.seat_upgrade_allowed?' do
    subject(:seat_upgrade_allowed) { described_class.seat_upgrade_allowed?(user_id) }

    let(:user_id) { build_stubbed(:user).id }

    context 'when on GitLab.com', :saas do
      it { is_expected.to be true }
    end

    context 'when on Self-Managed' do
      let(:license) { create(:license, plan: License::PREMIUM_PLAN) }
      let(:seats) { 1000 }

      before do
        allow(License).to receive(:current).and_return(license)
        allow(license).to receive(:seats).and_return(seats)
      end

      context 'when block seat overages is disabled' do
        before do
          stub_application_setting(seat_control: 0)
        end

        it { is_expected.to be true }
      end

      context 'when block seat overages is enabled and seats are available' do
        let(:seats) { User.count + 1 }

        before do
          stub_application_setting(seat_control: 2)
        end

        it { is_expected.to be true }
      end

      context 'when block seat overages is enabled and seats are not available' do
        let(:seats) { User.count }

        before do
          stub_application_setting(seat_control: 2)
        end

        it { is_expected.to be false }

        context 'when user is already billable' do
          let(:billable_user) { create(:user) }
          let(:user_id) { billable_user.id }

          before do
            allow(User).to receive(:billable).and_return(User.where(id: billable_user.id))
          end

          it 'returns true for already-billable users' do
            expect(seat_upgrade_allowed).to be true
          end
        end

        context 'with a bot account' do
          let(:user_id) { create(:user, :service_account) }

          it { is_expected.to be true }
        end
      end
    end
  end
end
