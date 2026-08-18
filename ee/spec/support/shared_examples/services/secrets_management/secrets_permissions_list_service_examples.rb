# frozen_string_literal: true

RSpec.shared_examples 'a service for listing secrets permissions' do |_resource_type|
  subject(:result) { service.execute }

  describe '#execute' do
    context 'when secrets manager is active' do
      before do
        provision_secrets_manager(secrets_manager, user)
      end

      context 'when only the default owner permission exists' do
        it 'returns the owner permission in the list of permissions' do
          expect(result).to be_success
          expect(result.payload[:secrets_permissions])
            .to match_array(
              have_attributes(
                principal_type: "Role",
                principal_id: Gitlab::Access::OWNER
              )
            )
        end
      end

      context 'when there are other secrets permissions' do
        let!(:other_user) { create(:user) }
        let!(:member_role) { create(:member_role, namespace: member_role_namespace) }
        let(:expired_at) { 2.days.from_now.iso8601 }

        before do
          resource.add_maintainer(other_user)

          update_permission(
            user: user, actions: %w[write read delete],
            principal: { id: other_user.id, type: 'User' }, expired_at: expired_at
          )
          update_permission(
            user: user, actions: %w[write read delete],
            principal: { id: Gitlab::Access::REPORTER, type: 'Role' }
          )
          update_permission(
            user: user, actions: %w[write read delete],
            principal: { id: member_role.id, type: 'MemberRole' }
          )
          update_permission(
            user: user, actions: %w[write read delete],
            principal: { id: shared_resource.id, type: 'Group' }
          )
        end

        it 'returns all secrets permissions' do
          expect(result).to be_success

          expected_actions = a_collection_containing_exactly("write", "read", "delete")
          expect(result.payload[:secrets_permissions])
            .to match_array([
              have_attributes(
                principal_type: "Role",
                principal_id: Gitlab::Access::OWNER,
                actions: expected_actions
              ),
              have_attributes(
                principal_type: "User",
                principal_id: other_user.id,
                granted_by: user.id,
                actions: expected_actions,
                expired_at: expired_at
              ),
              have_attributes(
                principal_type: "Role",
                principal_id: Gitlab::Access::REPORTER,
                granted_by: user.id,
                actions: expected_actions,
                expired_at: nil
              ),
              have_attributes(
                principal_type: "MemberRole",
                principal_id: member_role.id,
                granted_by: user.id,
                actions: expected_actions,
                expired_at: nil
              ),
              have_attributes(
                principal_type: "Group",
                principal_id: shared_resource.id,
                granted_by: user.id,
                actions: expected_actions,
                expired_at: nil
              )
            ])
        end
      end

      context 'when a permission grants read_value (api_value_capabilities)' do
        let!(:read_value_user) { create(:user) }

        before do
          resource.add_developer(read_value_user)

          update_permission(
            user: user, actions: %w[read write delete read_value],
            principal: { id: read_value_user.id, type: 'User' }
          )
        end

        it 'reads the read_value action back from the API policy' do
          expect(result).to be_success

          expect(result.payload[:secrets_permissions]).to include(
            have_attributes(
              principal_type: 'User',
              principal_id: read_value_user.id,
              actions: a_collection_containing_exactly('read', 'write', 'delete', 'read_value')
            )
          )
        end
      end
    end

    context 'when secrets manager is not active' do
      it 'returns an error' do
        result = service.execute
        expect(result).to be_error
        expect(result.message).to eq("Secrets manager is not active")
      end
    end
  end
end
