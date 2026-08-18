# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    :orchestrated,
    feature_category: :secrets_management
  ) do
    include_context 'group secrets manager base'
    describe 'Create on group secret permissions' do
      context 'when an owner creates permissions for a shared group' do
        let(:new_group) { create(:group) }

        before do
          new_group.add_member(owner, Resource::Members::AccessLevel::OWNER)

          Support::Waiter.wait_until(max_duration: 10, sleep_interval: 1) do
            new_group.reload!
            new_group.find_member(owner.username).present?
          end

          Support::API.post(
            Runtime::API::Request.new(Runtime::User::Store.admin_api_client, "/groups/#{group.id}/share").url,
            { group_id: new_group.id, group_access: Resource::Members::AccessLevel::DEVELOPER }
          )
          group.reload!
        end

        it 'successfully creates permissions' do
          Flow::Login.while_signed_in(as: owner) do
            group.visit!

            Page::Group::Menu.perform(&:go_to_general_settings)
            Page::Group::Settings::General.perform do |settings|
              scopes = %w[read write delete]
              settings.add_group_permission(group_path: new_group.full_path, scopes: scopes)
              expect(settings).to have_group_permission(group_name: new_group.name, scopes: scopes)
            end
          end
        end
      end

      context 'when owner creates permission for non-group user' do
        let!(:non_group_user) { create(:user) }

        it 'fails to create the secret permission' do
          Flow::Login.while_signed_in(as: owner) do
            group.visit!

            Page::Group::Menu.perform(&:go_to_general_settings)
            Page::Group::Settings::General.perform do |settings|
              expect(settings).not_to have_user_in_dropdown(username: non_group_user.username)
            end
          end
        end
      end

      context 'when owner creates permission for developer-role without read permission' do
        it 'fails to create the secret permission' do
          Flow::Login.while_signed_in(as: owner) do
            group.visit!

            Page::Group::Menu.perform(&:go_to_general_settings)
            Page::Group::Settings::General.perform do |settings|
              scopes = %w[write delete]
              settings.add_role_permission(role_name: 'Developer', scopes: scopes)
              expect(settings.alert_text).to eq('Actions must include read, read_metadata, or read_value')
            end
          end
        end
      end
    end
  end
end
