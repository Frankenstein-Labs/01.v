# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    :orchestrated,
    feature_category: :secrets_management
  ) do
    describe 'Project Secrets Manager Feature Provision' do
      include QA::EE::Support::Helpers::SecretsManagement::SecretsManagerHelper # rubocop: disable Cop/InjectEnterpriseEditionModule -- Helpers are added this way
      let(:owner) { create(:user) }
      let(:project) { create(:project, :with_readme, name: 'secrets-manager-test-project') }

      before do
        # SM availability now requires (FF AND enrollment). Enroll the instance
        # so SM is available across projects in the test run.
        enroll_instance_in_secrets_manager
      end

      it 'enables project secrets manager, checks owner permissions and disables secrets manager' do
        project.add_member(owner, Resource::Members::AccessLevel::OWNER)

        Support::Waiter.wait_until(max_duration: 10, sleep_interval: 1) do
          project.reload!
          project.find_member(owner.username).present?
        end

        Flow::Login.while_signed_in(as: owner) do
          project.visit!
          Page::Project::Menu.perform(&:go_to_general_settings)

          Page::Project::Settings::Main.perform do |settings|
            settings.expand_visibility_project_features_permissions do |permissions|
              expect(permissions).to have_secrets_manager_section
              permissions.enable_secrets_manager

              Support::Waiter.wait_until(max_duration: 60, sleep_interval: 2) do
                permissions.has_secrets_manager_enabled?
              end

              expect(permissions).to have_secrets_manager_enabled
              expect(permissions).to have_secrets_manager_permissions_section
              expect(permissions).to have_owner_permissions_in_roles_tab

              permissions.disable_secrets_manager

              Support::Waiter.wait_until(max_duration: 60, sleep_interval: 2) do
                !permissions.has_secrets_manager_enabled?
              end

              expect(permissions).not_to have_secrets_manager_enabled
            end
          end
        end
      end
    end
  end
end
