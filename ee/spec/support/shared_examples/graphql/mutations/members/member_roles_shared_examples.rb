# frozen_string_literal: true

RSpec.shared_examples 'a mutation that creates a member role' do
  it 'returns success', :aggregate_failures do
    post_graphql_mutation(mutation, current_user: current_user)

    expect(graphql_errors).to be_nil

    expect(create_member_role['memberRole']['enabledPermissions']['nodes'].flat_map(&:values))
      .to match_array(permissions)
  end

  it 'creates the member role', :aggregate_failures do
    expect { post_graphql_mutation(mutation, current_user: current_user) }
      .to change { MemberRole.count }.by(1)

    member_role = MemberRole.last
    enabled_permissions = member_role.enabled_permissions.keys

    expect(enabled_permissions).to match_array(enabled_permissions_result)
  end
end
