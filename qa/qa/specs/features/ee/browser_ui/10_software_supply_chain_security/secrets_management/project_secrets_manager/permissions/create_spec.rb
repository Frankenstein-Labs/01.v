# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    :orchestrated,
    feature_category: :secrets_management
  ) do
    include_context 'secrets manager base'
    describe 'Create on project secret permissions' do
      context 'when an owner creates permissions for a project-group' do
        let(:new_group) { create(:group) }

        before do
          new_group.add_member(owner, Resource::Members::AccessLevel::OWNER)

          Support::Waiter.wait_until(max_duration: 10, sleep_interval: 1) do
            new_group.reload!
            new_group.find_member(owner.username).present?
          end

          Support::API.post(
            Runtime::API::Request.new(Runtime::User::Store.admin_api_client, "/projects/#{project.id}/share").url,
            { group_id: new_group.id, group_access: 30 } # 30 = Developer
          )
          Support::Waiter.wait_until(max_duration: 10, sleep_interval: 1) do
            project.reload!
          end
        end

        it 'successfully creates permissions' do
          Flow::Login.while_signed_in(as: owner) do
            project.visit!

            Page::Project::Menu.perform(&:go_to_general_settings)
            Page::Project::Settings::Main.perform do |settings|
              settings.expand_visibility_project_features_permissions do |permissions_page|
                scopes = %w[read write delete]
                permissions_page.add_group_permission(group_path: new_group.full_path, scopes: scopes)
                expect(permissions_page).to have_group_permission(group_name: new_group.name, scopes: scopes)
              end
            end
          end
        end
      end

      context 'when owner creates permission for non-project user' do
        let!(:non_project_user) { create(:user) }

        it 'fails to create the secret permission' do
          Flow::Login.while_signed_in(as: owner) do
            project.visit!

            Page::Project::Menu.perform(&:go_to_general_settings)
            Page::Project::Settings::Main.perform do |settings|
              settings.expand_visibility_project_features_permissions do |permissions_page|
                expect(permissions_page).not_to have_user_in_dropdown(username: non_project_user.username)
              end
            end
          end
        end
      end

      context 'when owner creates permission for developer-role without read permission' do
        it 'fails to create the secret permission' do
          Flow::Login.while_signed_in(as: owner) do
            project.visit!

            Page::Project::Menu.perform(&:go_to_general_settings)
            Page::Project::Settings::Main.perform do |settings|
              settings.expand_visibility_project_features_permissions do |permissions_page|
                scopes = %w[write delete]
                permissions_page.add_role_permission(role_name: 'Developer', scopes: scopes)
                expect(permissions_page.alert_text).to eq('Actions must include read, read_metadata, or read_value')
              end
            end
          end
        end
      end
    end
  end
end
