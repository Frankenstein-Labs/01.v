# frozen_string_literal: true

RSpec.shared_context 'with multiple users in a group with custom roles' do
  let_it_be(:invited_group, freeze: false) { create(:group) }

  let_it_be(:guest_read_runners, freeze: false) do
    create(:member_role, :guest, :instance, read_runners: true)
  end

  let_it_be(:guest_read_vulnerability, freeze: false) do
    create(:member_role, :guest, :instance, read_vulnerability: true)
  end

  let_it_be(:developer_admin_vulnerability, freeze: false) do
    create(:member_role, :developer, :instance, admin_vulnerability: true, read_vulnerability: true)
  end

  let_it_be(:user_a, freeze: false) do
    create(:group_member, :guest, source: invited_group, member_role: guest_read_runners)
  end

  let_it_be(:user_b, freeze: false) do
    create(:group_member, :guest, source: invited_group, member_role: guest_read_vulnerability)
  end

  let_it_be(:user_c, freeze: false) { create(:group_member, :guest, source: invited_group) }
  let_it_be(:user_d, freeze: false) { create(:group_member, :developer, source: invited_group) }
  let_it_be(:user_e, freeze: false) do
    create(:group_member, :developer, source: invited_group, member_role: developer_admin_vulnerability)
  end
end

RSpec.shared_examples 'returns expected member role abilities' do
  using RSpec::Parameterized::TableSyntax

  where(:invited_group_access, :invited_group_member_role, :member, :expected_result) do
    Gitlab::Access::GUEST | nil | ref(:user_a) | []
    Gitlab::Access::GUEST | nil | ref(:user_b) | []
    Gitlab::Access::GUEST | nil | ref(:user_c) | []
    Gitlab::Access::GUEST | nil | ref(:user_d) | []
    Gitlab::Access::GUEST | nil | ref(:user_e) | []
    Gitlab::Access::GUEST | ref(:guest_read_runners) | ref(:user_a) | [:read_runners]
    Gitlab::Access::GUEST | ref(:guest_read_runners) | ref(:user_b) | [:read_vulnerability]
    Gitlab::Access::GUEST | ref(:guest_read_runners) | ref(:user_c) | []
    Gitlab::Access::GUEST | ref(:guest_read_runners) | ref(:user_d) | [:read_runners]
    Gitlab::Access::GUEST | ref(:guest_read_runners) | ref(:user_e) | [:read_runners]
    Gitlab::Access::GUEST | ref(:guest_read_vulnerability) | ref(:user_a) | [:read_runners]
    Gitlab::Access::GUEST | ref(:guest_read_vulnerability) | ref(:user_b) | [:read_vulnerability]
    Gitlab::Access::GUEST | ref(:guest_read_vulnerability) | ref(:user_c) | []
    Gitlab::Access::GUEST | ref(:guest_read_vulnerability) | ref(:user_d) | [:read_vulnerability]
    Gitlab::Access::GUEST | ref(:guest_read_vulnerability) | ref(:user_e) | [:read_vulnerability]
    Gitlab::Access::DEVELOPER | nil | ref(:user_a) | [:read_runners]
    Gitlab::Access::DEVELOPER | nil | ref(:user_b) | [:read_vulnerability]
    Gitlab::Access::DEVELOPER | nil | ref(:user_c) | []
    Gitlab::Access::DEVELOPER | nil | ref(:user_d) | []
    Gitlab::Access::DEVELOPER | nil | ref(:user_e) | []
    Gitlab::Access::DEVELOPER | ref(:developer_admin_vulnerability) | ref(:user_a) | [:read_runners]
    Gitlab::Access::DEVELOPER | ref(:developer_admin_vulnerability) | ref(:user_b) | [:read_vulnerability]
    Gitlab::Access::DEVELOPER | ref(:developer_admin_vulnerability) | ref(:user_c) | []
    Gitlab::Access::DEVELOPER | ref(:developer_admin_vulnerability) | ref(:user_d) | []
    Gitlab::Access::DEVELOPER | ref(:developer_admin_vulnerability) | ref(:user_e) | [:read_vulnerability,
      :admin_vulnerability]
  end

  with_them do
    before do
      create(:group_group_link,
        group_access: invited_group_access,
        member_role: invited_group_member_role,
        shared_group: group,
        shared_with_group: invited_group
      )
    end

    let(:user) { member.user }

    before do
      MemberRole.update_all(namespace_id: group.id, organization_id: nil)
    end

    it 'returns expected result' do
      expect(result[source.id]).to match_array(expected_result)
    end
  end
end

RSpec.shared_context 'with a user in multiple groups with custom role' do
  let_it_be(:group_a, freeze: false) { create(:group) }
  let_it_be(:group_b, freeze: false) { create(:group) }

  let_it_be(:user, freeze: false) { create(:user) }

  let_it_be(:reporter_member_role, freeze: false) do
    create(:member_role, :reporter, :instance, admin_cicd_variables: true)
  end

  let_it_be(:member_a, freeze: false) { create(:group_member, :reporter, source: group_a, user: user) }
  let_it_be(:member_b, freeze: false) do
    create(:group_member, :reporter, source: group_b, user: user, member_role: reporter_member_role)
  end
end

RSpec.shared_examples 'returns expected member role abilities for the user' do
  using RSpec::Parameterized::TableSyntax

  where(:group_a_access, :group_a_member_role, :group_b_access, :group_b_member_role, :expected_result) do
    Gitlab::Access::REPORTER | nil | Gitlab::Access::DEVELOPER | nil | [:admin_cicd_variables]
    Gitlab::Access::REPORTER | nil | Gitlab::Access::REPORTER | nil | []
    Gitlab::Access::REPORTER | nil | Gitlab::Access::REPORTER | ref(:reporter_member_role) | [:admin_cicd_variables]
  end

  with_them do
    before do
      create(:group_group_link,
        group_access: group_a_access,
        member_role: group_a_member_role,
        shared_group: group,
        shared_with_group: group_a
      )

      create(:group_group_link,
        group_access: group_b_access,
        member_role: group_b_member_role,
        shared_group: group,
        shared_with_group: group_b
      )
    end

    before do
      MemberRole.update_all(namespace_id: group.id, organization_id: nil)
    end

    it 'returns expected result' do
      expect(result[source.id]).to match_array(expected_result)
    end
  end
end
