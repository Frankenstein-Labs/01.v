# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    :orchestrated,
    :requires_admin,
    feature_category: :secrets_management
  ) do
    include_context 'group secrets manager base'
    describe 'Group secret access via group sharing' do
      def shared_user
        @shared_user ||= create(:user)
      end

      def sharing_group
        @sharing_group ||= create(:group)
      end

      def secret_name
        @secret_name ||= "group_sharing_secret"
      end

      before(:context) do
        sharing_group.add_member(shared_user, Resource::Members::AccessLevel::OWNER)

        Support::Waiter.wait_until(max_duration: 10, sleep_interval: 1) do
          sharing_group.reload!
          sharing_group.find_member(shared_user.username).present?
        end

        # shared_user has no direct membership in group; their only access flows through this
        # GroupGroupLink. Regression guard for work item 602488: a share-only user used to get
        # role_id "0" in their GroupUserJwt, so OpenBao denied every secrets operation.
        response = Support::API.post(
          Runtime::API::Request.new(Runtime::User::Store.admin_api_client, "/groups/#{group.id}/share").url,
          { group_id: sharing_group.id, group_access: Resource::Members::AccessLevel::OWNER }
        )
        raise "Failed to share group: #{response.body}" unless response.code == 201

        group.reload!

        Flow::Login.while_signed_in(as: owner) do
          group.visit!

          Page::Group::Menu.perform(&:go_to_secrets_manager)
          EE::Page::Group::Secure::SecretsManager.perform do |secrets_page|
            secrets_page.click_new_secret
            secrets_page.create_secret(
              name: secret_name,
              value: 'testvalue',
              description: "Secret for group sharing access test",
              environment: '*'
            )
          end
        end
      end

      context 'when the user accesses the group secrets manager via group sharing' do
        it 'can read the secret without a permission error' do
          Flow::Login.while_signed_in(as: shared_user) do
            group.visit!

            Page::Group::Menu.perform(&:go_to_secrets_manager)
            EE::Page::Group::Secure::SecretsManager.perform do |secrets_page|
              expect(secrets_page).to have_secret_in_table(secret_name)
            end
          end
        end
      end
    end
  end
end
