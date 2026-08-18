# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::SelfManaged::NonBillableUsersFinder, feature_category: :seat_cost_management do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:billable_user) { create(:user) }
  let_it_be(:guest_user) { create(:user) }
  let_it_be(:minimal_access_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:ultimate_license) { create(:license, plan: License::ULTIMATE_PLAN) }

  let!(:non_billable_guest_member) { create(:group_member, :guest, user: guest_user, group: group) }
  let!(:non_billable_minimal_access_member) do
    create(:group_member, :minimal_access, user: minimal_access_user, group: group)
  end

  let_it_be(:billable_role) do
    create(
      :member_role,
      :guest,
      organization: guest_user.organization,
      namespace: nil,
      read_vulnerability: true
    )
  end

  let_it_be(:non_billable_role) do
    create(
      :member_role,
      :guest,
      organization: guest_user.organization,
      namespace: nil,
      read_code: true
    )
  end

  let!(:billable_group_member) { create(:group_member, :developer, user: billable_user, group: group) }
  let(:user_ids) { [billable_user.id, guest_user.id, minimal_access_user.id] }

  subject(:non_billable_user_finder) do
    described_class.new(current_user, user_ids).execute
  end

  describe '#execute' do
    shared_examples 'returns empty' do
      it 'returns an empty relation' do
        expect(non_billable_user_finder).to be_empty
      end
    end

    context 'when member_promotion_management_enabled? returns false' do
      it_behaves_like 'returns empty'
    end

    context 'when member_promotion_management_enabled? returns true' do
      before do
        stub_application_setting(enable_member_promotion_management: true)
        allow(License).to receive(:current).and_return(ultimate_license)
      end

      context 'when current_user is nil' do
        let(:current_user) { nil }

        it_behaves_like 'returns empty'
      end

      context 'with an empty array of user IDs' do
        let(:user_ids) { [] }

        it_behaves_like 'returns empty'
      end

      context 'with an array of user IDs' do
        context 'with users that are existing members' do
          it 'returns non-billable users' do
            expect(non_billable_user_finder).to match_array([minimal_access_user, guest_user])
          end

          context 'with member roles' do
            before do
              non_billable_guest_member.update!(member_role: member_role)
            end

            context 'when guest role is elevated' do
              let(:member_role) { billable_role }

              it 'returns only minimal access' do
                expect(non_billable_user_finder).to contain_exactly(minimal_access_user)
              end
            end

            context 'when guest role is not elevated' do
              let(:member_role) { non_billable_role }

              it 'returns both guest and minimal access' do
                expect(non_billable_user_finder).to match_array([minimal_access_user, guest_user])
              end
            end
          end

          context 'with users having multiple memberships' do
            let_it_be(:user) { create(:user) }
            let(:role_in_group1) { Gitlab::Access::GUEST }
            let(:role_in_group2) { Gitlab::Access::GUEST }

            let!(:guest_member) do
              create(:group_member, user: user, access_level: role_in_group1)
            end

            let!(:another_guest_member) do
              create(:group_member, user: user, access_level: role_in_group2)
            end

            let(:user_ids) { super() << user.id }

            shared_examples "skips user because user is billable" do
              it 'does not return billable user' do
                expect(non_billable_user_finder).to match_array([minimal_access_user, guest_user])
              end
            end

            shared_examples "returns user because user is non billable" do
              it 'returns user' do
                expect(non_billable_user_finder).to match_array([
                  minimal_access_user, guest_user, user
                ])
              end
            end

            context 'with both non billable roles' do
              it_behaves_like "returns user because user is non billable"
            end

            context 'with one billable role and one non billable role' do
              let(:role_in_group2) { Gitlab::Access::DEVELOPER }

              it_behaves_like "skips user because user is billable"
            end

            context 'with both billable roles' do
              let(:role_in_group1) { Gitlab::Access::DEVELOPER }
              let(:role_in_group2) { Gitlab::Access::DEVELOPER }

              it_behaves_like "skips user because user is billable"
            end

            context 'with elevation scenarios' do
              context 'with just one evelated role' do
                before do
                  another_guest_member.update!(member_role: billable_role)
                end

                it_behaves_like "skips user because user is billable"
              end

              context 'with one evelated and one non elevated role' do
                let_it_be_with_reload(:third_guest_member) do
                  create(:group_member, user: user, access_level: Gitlab::Access::GUEST)
                end

                before do
                  another_guest_member.update!(member_role: billable_role)

                  third_guest_member.update!(member_role: non_billable_role)
                end

                it_behaves_like "skips user because user is billable"
              end

              context 'with just non elevated role' do
                before do
                  another_guest_member.update!(member_role: non_billable_role)
                end

                it_behaves_like "returns user because user is non billable"
              end
            end
          end
        end

        context 'with users without any memberships' do
          let(:users) { create_list(:user, 2) }
          let(:user_ids) { users.map(&:id) }

          it 'returns all new users' do
            expect(non_billable_user_finder).to match_array(users)
          end
        end
      end
    end
  end
end
