# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupMembersFinder, feature_category: :groups_and_projects do
  include MemberRoleHelpers
  using RSpec::Parameterized::TableSyntax

  subject(:finder) { described_class.new(group) }

  let_it_be(:group) { create :group }

  let_it_be(:non_owner_access_level) { Gitlab::Access.options.values.sample }
  let_it_be(:group_owner_membership) { group.add_member(create(:user), Gitlab::Access::OWNER) }
  let_it_be(:group_member_membership) { group.add_member(create(:user), non_owner_access_level) }
  let_it_be(:dedicated_member_account_membership) do
    group.add_member(create(:user, managing_group: group), non_owner_access_level)
  end

  describe '#execute' do
    context 'with custom roles' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      let_it_be(:group)                { create(:group) }
      let_it_be(:sub_group)            { create(:group, parent: group) }
      let_it_be(:sub_sub_group)        { create(:group, parent: sub_group) }
      let_it_be(:public_shared_group)  { create(:group, :public) }
      let_it_be(:private_shared_group) { create(:group, :private) }
      let_it_be(:user1)                { create(:user) }
      let_it_be(:user2)                { create(:user) }
      let_it_be(:user3)                { create(:user) }
      let_it_be(:user4)                { create(:user) }
      let_it_be(:user5_2fa)            { create(:user, :two_factor_via_otp) }

      let_it_be(:link) do
        create(:group_group_link, group_access: ::Gitlab::Access::OWNER, shared_group: group,     shared_with_group: public_shared_group)
        create(:group_group_link, group_access: ::Gitlab::Access::OWNER, shared_group: sub_group, shared_with_group: private_shared_group)
      end

      let(:groups) do
        {
          group: group,
          sub_group: sub_group,
          sub_sub_group: sub_sub_group,
          public_shared_group: public_shared_group,
          private_shared_group: private_shared_group
        }
      end

      let_it_be(:public_shared_group_custom_maintainer_role) { create(:member_role, :maintainer, namespace: public_shared_group) }
      let_it_be(:public_shared_group_custom_developer_role) { create(:member_role, :developer, namespace: public_shared_group) }
      let_it_be(:public_shared_group_custom_reporter_role) { create(:member_role, :reporter, namespace: public_shared_group) }

      let_it_be(:members) do
        group_custom_maintainer_role = create(:member_role, :maintainer, namespace: group)
        group_custom_developer_role = create(:member_role, :developer, namespace: group)
        group_custom_reporter_role = create(:member_role, :reporter, namespace: group)
        private_shared_group_custom_maintainer_role = create(:member_role, :maintainer, namespace: private_shared_group)
        private_shared_group_custom_developer_role = create(:member_role, :developer, namespace: private_shared_group)
        private_shared_group_custom_reporter_role = create(:member_role, :reporter, namespace: private_shared_group)
        {
          user1_sub_sub_group: create(:group_member, :maintainer, group: sub_sub_group, user: user1, member_role: group_custom_maintainer_role),
          user1_sub_group: create(:group_member, :developer, group: sub_group, user: user1, member_role: group_custom_developer_role),
          user1_group: create(:group_member, :reporter, group: group, user: user1, member_role: group_custom_reporter_role),
          user1_public_shared_group: create(:group_member, :maintainer, group: public_shared_group, user: user1, member_role: public_shared_group_custom_maintainer_role),
          user1_private_shared_group: create(:group_member, :maintainer, group: private_shared_group, user: user1, member_role: private_shared_group_custom_maintainer_role),
          user2_sub_sub_group: create(:group_member, :reporter, group: sub_sub_group, user: user2, member_role: group_custom_reporter_role),
          user2_sub_group: create(:group_member, :developer, group: sub_group, user: user2, member_role: group_custom_developer_role),
          user2_group: create(:group_member, :maintainer, group: group, user: user2, member_role: group_custom_maintainer_role),
          user2_public_shared_group: create(:group_member, :developer, group: public_shared_group, user: user2, member_role: public_shared_group_custom_developer_role),
          user2_private_shared_group: create(:group_member, :developer, group: private_shared_group, user: user2, member_role: private_shared_group_custom_developer_role),
          user3_sub_sub_group: create(:group_member, :developer, group: sub_sub_group, user: user3, expires_at: 1.day.from_now, member_role: group_custom_developer_role),
          user3_sub_group: create(:group_member, :developer, group: sub_group, user: user3, expires_at: 2.days.from_now, member_role: group_custom_developer_role),
          user3_group: create(:group_member, :reporter, group: group, user: user3, member_role: group_custom_reporter_role),
          user3_public_shared_group: create(:group_member, :reporter, group: public_shared_group, user: user3, member_role: public_shared_group_custom_reporter_role),
          user3_private_shared_group: create(:group_member, :reporter, group: private_shared_group, user: user3, member_role: private_shared_group_custom_reporter_role),
          user4_sub_sub_group: create(:group_member, :reporter, group: sub_sub_group, user: user4, member_role: group_custom_reporter_role),
          user4_sub_group: create(:group_member, :developer, group: sub_group, user: user4, expires_at: 1.day.from_now, member_role: group_custom_developer_role),
          user4_group: create(:group_member, :developer, group: group, user: user4, expires_at: 2.days.from_now, member_role: group_custom_developer_role),
          user4_public_shared_group: create(:group_member, :developer, group: public_shared_group, user: user4, member_role: public_shared_group_custom_developer_role),
          user4_private_shared_group: create(:group_member, :developer, group: private_shared_group, user: user4, member_role: private_shared_group_custom_developer_role),
          user5_private_shared_group: create(:group_member, :developer, group: private_shared_group, user: user5_2fa, member_role: private_shared_group_custom_developer_role)
        }
      end

      subject(:result) do
        described_class
          .new(groups[subject_group], params: { with_custom_role: true })
          .execute(include_relations: subject_relations)
      end

      # rubocop: disable Layout/ArrayAlignment
      where(:subject_relations, :subject_group, :expected_members) do
        []                                                       | :group         | []
        GroupMembersFinder::DEFAULT_RELATIONS                    | :group         | [:user1_group, :user2_group, :user3_group, :user4_group]
        [:direct]                                                | :group         | [:user1_group, :user2_group, :user3_group, :user4_group]
        [:inherited]                                             | :group         | []
        [:descendants]                                           | :group         | [:user1_sub_group, :user1_sub_sub_group,
                                                                                     :user2_sub_group, :user2_sub_sub_group,
                                                                                     :user3_sub_group, :user3_sub_sub_group,
                                                                                     :user4_sub_group, :user4_sub_sub_group]
        [:shared_from_groups]                                    | :group         | [:user1_public_shared_group, :user2_public_shared_group, :user3_public_shared_group, :user4_public_shared_group]
        [:direct, :inherited, :descendants, :shared_from_groups] | :group         | [:user1_group, :user1_sub_group, :user1_sub_sub_group, :user1_public_shared_group,
                                                                                     :user2_group, :user2_sub_group, :user2_sub_sub_group, :user2_public_shared_group,
                                                                                     :user3_group, :user3_sub_group, :user3_sub_sub_group, :user3_public_shared_group,
                                                                                     :user4_group, :user4_sub_group, :user4_sub_sub_group, :user4_public_shared_group]
        []                                                       | :sub_group     | []
        GroupMembersFinder::DEFAULT_RELATIONS                    | :sub_group     | [:user1_group, :user1_sub_group,
                                                                                     :user2_group, :user2_sub_group,
                                                                                     :user3_group, :user3_sub_group,
                                                                                     :user4_group, :user4_sub_group]
        [:direct]                                                | :sub_group     | [:user1_sub_group, :user2_sub_group, :user3_sub_group, :user4_sub_group]
        [:inherited]                                             | :sub_group     | [:user1_group, :user2_group, :user3_group, :user4_group]
        [:descendants]                                           | :sub_group     | [:user1_sub_sub_group, :user2_sub_sub_group, :user3_sub_sub_group, :user4_sub_sub_group]
        [:shared_from_groups]                                    | :sub_group     | [:user1_public_shared_group, :user2_public_shared_group, :user3_public_shared_group, :user4_public_shared_group]
        [:direct, :inherited, :descendants, :shared_from_groups] | :sub_group     | [:user1_group, :user1_sub_group, :user1_sub_sub_group, :user1_public_shared_group,
                                                                                     :user2_group, :user2_sub_group, :user2_sub_sub_group, :user2_public_shared_group,
                                                                                     :user3_group, :user3_sub_group, :user3_sub_sub_group, :user3_public_shared_group,
                                                                                     :user4_group, :user4_sub_group, :user4_sub_sub_group, :user4_public_shared_group]
        []                                                       | :sub_sub_group | []
        GroupMembersFinder::DEFAULT_RELATIONS                    | :sub_sub_group | [:user1_group, :user1_sub_group, :user1_sub_sub_group,
                                                                                     :user2_group, :user2_sub_group, :user2_sub_sub_group,
                                                                                     :user3_group, :user3_sub_group, :user3_sub_sub_group,
                                                                                     :user4_group, :user4_sub_group, :user4_sub_sub_group]
        [:direct]                                                | :sub_sub_group | [:user1_sub_sub_group, :user2_sub_sub_group, :user3_sub_sub_group, :user4_sub_sub_group]
        [:inherited]                                             | :sub_sub_group | [:user1_group, :user1_sub_group,
                                                                                     :user2_group, :user2_sub_group,
                                                                                     :user3_group, :user3_sub_group,
                                                                                     :user4_group, :user4_sub_group]
        [:descendants]                                           | :sub_sub_group | []
        [:shared_from_groups]                                    | :sub_sub_group | [:user1_public_shared_group, :user2_public_shared_group, :user3_public_shared_group, :user4_public_shared_group]
        [:direct, :inherited, :descendants, :shared_from_groups] | :sub_sub_group | [:user1_group, :user1_sub_group, :user1_sub_sub_group, :user1_public_shared_group,
                                                                                     :user2_group, :user2_sub_group, :user2_sub_sub_group, :user2_public_shared_group,
                                                                                     :user3_group, :user3_sub_group, :user3_sub_sub_group, :user3_public_shared_group,
                                                                                     :user4_group, :user4_sub_group, :user4_sub_sub_group, :user4_public_shared_group]
      end
      # rubocop: enable Layout/ArrayAlignment
      with_them do
        context 'when `use_user_group_member_roles_members_page` feature flag is disabled' do
          before do
            stub_feature_flags(use_user_group_member_roles_members_page: false)
          end

          it 'returns correct members' do
            expect(result.to_a).to match_array(expected_members.map { |name| members[name] })
          end
        end

        context 'when `use_user_group_member_roles_members_page` feature flag is enabled' do
          before do
            stub_feature_flags(use_user_group_member_roles_members_page: true)
          end

          it 'returns correct members' do
            expect(result.to_a).to match_array(expected_members.map { |name| members[name] })
          end
        end
      end

      context 'member roles' do
        subject(:shared_member_roles) do
          described_class
            .new(groups[:sub_group], params: { with_custom_role: true })
            .execute(include_relations: [:shared_from_groups])
            .to_a
            .map(&:member_role_id)
        end

        let_it_be(:expected_member_roles) do
          [
            public_shared_group_custom_maintainer_role.id,
            public_shared_group_custom_developer_role.id,
            public_shared_group_custom_reporter_role.id,
            public_shared_group_custom_developer_role.id
          ]
        end

        context 'when `use_user_group_member_roles_members_page` feature flag is disabled' do
          before do
            stub_feature_flags(use_user_group_member_roles_members_page: false)
          end

          it 'returns the correct member roles of the members shared through group sharing' do
            expect(shared_member_roles).to match_array(expected_member_roles)
          end
        end

        context 'when `use_user_group_member_roles_members_page` feature flag is enabled' do
          before do
            stub_feature_flags(use_user_group_member_roles_members_page: true)
          end

          it 'returns the correct member roles of the members shared through group sharing' do
            expect(shared_member_roles).to match_array(expected_member_roles)
          end
        end
      end
    end

    context 'minimal access' do
      let_it_be(:group_minimal_access_membership) do
        create(:group_member, :minimal_access, source: group)
      end

      context 'when group does not allow minimal access members' do
        before do
          stub_licensed_features(minimal_access_role: false)
        end

        it 'returns only members with full access' do
          result = finder.execute(include_relations: [:direct, :descendants])

          expect(result.to_a).to match_array([group_owner_membership, group_member_membership, dedicated_member_account_membership])
        end
      end

      context 'when group allows minimal access members' do
        before do
          stub_licensed_features(minimal_access_role: true)
        end

        it 'also returns members with minimal access' do
          result = finder.execute(include_relations: [:direct, :descendants])

          expect(result.to_a).to match_array([group_owner_membership, group_member_membership, dedicated_member_account_membership, group_minimal_access_membership])
        end
      end
    end

    context 'filter by enterprise users', :saas do
      let_it_be(:enterprise_user_member_1_of_root_group) { group.add_developer(create(:user, enterprise_group_id: group.id)) }
      let_it_be(:enterprise_user_member_2_of_root_group) { group.add_developer(create(:user, enterprise_group_id: group.id)) }

      let(:all_members) do
        [
          group_owner_membership,
          group_member_membership,
          dedicated_member_account_membership,
          enterprise_user_member_1_of_root_group,
          enterprise_user_member_2_of_root_group
        ]
      end

      context 'when domain_verification feature is available for the group' do
        before do
          stub_licensed_features(domain_verification: true)
        end

        context 'when requested by owner' do
          let(:current_user) { group_owner_membership.user }

          context 'direct members of the group' do
            it 'returns Enterprise members when the filter is `true`' do
              result = described_class.new(group, current_user, params: { enterprise: 'true' }).execute

              expect(result.to_a).to match_array([enterprise_user_member_1_of_root_group, enterprise_user_member_2_of_root_group])
            end

            it 'returns members that are not Enterprise members when the filter is `false`' do
              result = described_class.new(group, current_user, params: { enterprise: 'false' }).execute

              expect(result.to_a).to match_array([group_owner_membership, group_member_membership, dedicated_member_account_membership])
            end

            it 'returns all members when the filter is not specified' do
              result = described_class.new(group, current_user, params: {}).execute

              expect(result.to_a).to match_array(all_members)
            end

            it 'returns all members when the filter is not either of `true` or `false`' do
              result = described_class.new(group, current_user, params: { enterprise: 'not-valid' }).execute

              expect(result.to_a).to match_array(all_members)
            end
          end
        end

        context 'when requested by non-owner' do
          let(:current_user) { group_member_membership.user }

          it 'returns all members, as non-owners do not have the ability to filter by Enterprise users' do
            result = described_class.new(group, current_user, params: { enterprise: 'true' }).execute

            expect(result.to_a).to match_array(all_members)
          end
        end
      end

      context 'when domain_verification feature is not available for the group' do
        before do
          stub_licensed_features(domain_verification: false)
        end

        context 'when requested by owner' do
          let(:current_user) { group_owner_membership.user }

          it 'returns all members, because `Enterprise` filter can only be applied on a paid top-level group with domain_verification feature available' do
            result = described_class.new(group, current_user, params: { enterprise: 'true' }).execute

            expect(result.to_a).to match_array(all_members)
          end
        end
      end
    end

    context 'filter by max role' do
      let_it_be(:member_role) { create(:member_role, :guest, namespace: group) }
      let_it_be(:member_with_custom_role) { create(:group_member, :guest, group: group, member_role: member_role) }
      let_it_be(:member_without_custom_role) { create(:group_member, :guest, group: group) }

      subject(:by_max_role) { described_class.new(group, create(:user), params: { max_role: max_role }).execute }

      context 'filter by custom role ID' do
        describe 'provided member role ID is incorrect' do
          using RSpec::Parameterized::TableSyntax

          where(:max_role) { [nil, '', 'custom', lazy { "xcustom-#{member_role.id}" }, lazy { "custom-#{member_role.id}x" }] }

          with_them do
            it { is_expected.to match_array(group.members) }
          end
        end

        describe 'none of the members have the provided member role ID' do
          let(:max_role) { "custom-#{non_existing_record_id}" }

          it { is_expected.to be_empty }
        end

        describe 'one of the members has the provided member role ID' do
          let(:max_role) { "custom-#{member_role.id}" }

          it { is_expected.to contain_exactly(member_with_custom_role) }
        end
      end

      context 'filter by max role minimal access' do
        let(:max_role) { 'static-5' }

        let_it_be(:member_with_minimal_access) { create(:group_member, :minimal_access, source: group) }

        context 'when group does not allow minimal access members' do
          before do
            stub_licensed_features(minimal_access_role: false)
          end

          it { is_expected.to match_array(group.members) }
        end

        context 'when group allows minimal access members' do
          before do
            stub_licensed_features(minimal_access_role: true)
          end

          it { is_expected.to contain_exactly(member_with_minimal_access) }
        end
      end
    end
  end
end
