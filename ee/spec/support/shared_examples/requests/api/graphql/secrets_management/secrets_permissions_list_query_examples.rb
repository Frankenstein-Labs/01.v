# frozen_string_literal: true

RSpec.shared_examples 'a GraphQL query for listing secrets permissions' do |resource_type|
  let(:error_message) do
    /The resource that you are attempting to access does not exist or you don't have permission to perform this action/i
  end

  subject(:post_graphql_query) { post_graphql(query, current_user: current_user) }

  context 'when secrets manager is active' do
    let!(:other_user) { create(:user) }
    let!(:member_role) { create(:member_role, namespace: member_role_namespace) }

    let(:expired_at) { 2.days.from_now.iso8601 }

    before do
      resource.add_maintainer(other_user)
      provision_secrets_manager(secrets_manager, current_user)

      update_permission(
        user: current_user, actions: %w[write read delete],
        principal: { id: other_user.id, type: 'User' }, expired_at: expired_at
      )
      update_permission(
        user: current_user, actions: %w[write read delete],
        principal: { id: Gitlab::Access::REPORTER, type: 'Role' }
      )
      update_permission(
        user: current_user, actions: %w[write read delete],
        principal: { id: member_role.id, type: 'MemberRole' }
      )
      update_permission(
        user: current_user, actions: %w[write read delete],
        principal: { id: shared_resource.id, type: 'Group' }
      )
    end

    shared_examples 'returns secrets permissions successfully' do
      it 'returns secrets permissions' do
        post_graphql_query

        expect(response).to have_gitlab_http_status(:success)

        expected_actions = a_collection_containing_exactly("WRITE", "DELETE", "READ")
        expect(graphql_data_at(query_name, :nodes))
          .to include(
            a_graphql_entity_for(
              principal: a_graphql_entity_for(
                type: "ROLE",
                id: Gitlab::Access::OWNER.to_s
              ),
              actions: expected_actions
            ),
            a_graphql_entity_for(
              principal: a_graphql_entity_for(
                type: "USER",
                id: other_user.id.to_s
              ),
              actions: expected_actions,
              granted_by: a_graphql_entity_for(current_user),
              expired_at: expired_at.to_date.iso8601
            ),
            a_graphql_entity_for(
              principal: a_graphql_entity_for(
                type: "ROLE",
                id: Gitlab::Access::REPORTER.to_s
              ),
              actions: expected_actions,
              granted_by: a_graphql_entity_for(current_user)
            ),
            a_graphql_entity_for(
              principal: a_graphql_entity_for(
                type: "MEMBER_ROLE",
                id: member_role.id.to_s
              ),
              actions: expected_actions,
              granted_by: a_graphql_entity_for(current_user)
            ),
            a_graphql_entity_for(
              principal: a_graphql_entity_for(
                type: "GROUP",
                id: shared_resource.id.to_s
              ),
              actions: expected_actions,
              granted_by: a_graphql_entity_for(current_user)
            )
          )
      end
    end

    context 'and user is a maintainer' do
      before do
        resource.add_maintainer(current_user)
      end

      it_behaves_like 'returns secrets permissions successfully'
    end

    context 'and user is an owner' do
      before do
        resource.add_owner(current_user)
      end

      it_behaves_like 'returns secrets permissions successfully'
    end

    context 'and a permission grants read_value' do
      let!(:read_value_user) { create(:user) }

      before do
        resource.add_owner(current_user)
        resource.add_developer(read_value_user)

        update_permission(
          user: current_user, actions: %w[read write delete read_value],
          principal: { id: read_value_user.id, type: 'User' }
        )
      end

      it 'returns the read_value action', :aggregate_failures do
        post_graphql_query

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_data_at(query_name, :nodes)).to include(
          a_graphql_entity_for(
            principal: a_graphql_entity_for(
              type: 'USER',
              id: read_value_user.id.to_s
            ),
            actions: a_collection_containing_exactly('READ', 'WRITE', 'DELETE', 'READ_VALUE')
          )
        )
      end
    end

    context 'and the user is not allowed to read secrets permissions' do
      it 'returns an error' do
        post_graphql_query

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to include(a_hash_including('message' => error_message))
      end
    end

    context 'and service results to a failure' do
      it 'returns the service error' do
        expect_next_instance_of(service_class) do |service|
          result = ServiceResponse.error(message: 'some error')
          expect(service).to receive(:execute).and_return(result)
        end

        resource.add_owner(current_user)
        post_graphql_query

        expect(graphql_errors).to include(a_hash_including('message' => 'some error'))
      end
    end

    context "when the #{resource_type} does not exist" do
      let(:resource_path) { 'non/existent/resource' }

      it 'returns an error' do
        resource.add_owner(current_user)
        post_graphql_query

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to include(a_hash_including('message' => error_message))
      end
    end
  end

  context 'when secrets manager is not active' do
    before do
      # Satisfy the SM-availability gate (license AND FF AND enrollment) so the
      # resolver reaches the service layer, which surfaces the "not active"
      # error we want to assert on.
      enroll_instance_in_secrets_manager
      secrets_manager # ensure the (non-provisioned) SM record exists
    end

    it 'returns a GraphQL error with the error message' do
      resource.add_owner(current_user)
      post_graphql_query

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_data_at(query_name)).to be_nil
      expect(graphql_errors).to include(
        a_hash_including('message' => 'Secrets manager is not active')
      )
    end
  end
end
