# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    :orchestrated,
    feature_category: :secrets_management
  ) do
    describe 'Group Secrets Manager Feature Provision' do
      include QA::EE::Support::Helpers::SecretsManagement::SecretsManagerHelper # rubocop: disable Cop/InjectEnterpriseEditionModule -- Helpers are added this way

      let(:owner) { create(:user) }
      let(:group) { create(:group) }

      before do
        # SM availability now requires (FF AND enrollment). Enroll the instance
        # so SM is available across groups in the test run.
        enroll_instance_in_secrets_manager
      end

      it 'enables group secrets manager, verifies default owner permissions, and disables secrets manager' do
        group.add_member(owner, Resource::Members::AccessLevel::OWNER)

        Support::Waiter.wait_until(max_duration: 30, sleep_interval: 1) do
          group.reload!
          group.find_member(owner.username).present?
        end

        Flow::Login.while_signed_in(as: owner) do
          group.visit!
          Page::Group::Menu.perform(&:go_to_general_settings)

          Page::Group::Settings::General.perform do |settings|
            expect(settings).to have_secrets_manager_section
            settings.enable_secrets_manager

            Support::Waiter.wait_until(max_duration: 60, sleep_interval: 2) do
              settings.has_secrets_manager_enabled?
            end

            expect(settings).to have_secrets_manager_enabled
            expect(settings).to have_secrets_manager_permissions_section
            expect(settings).to have_owner_permissions_in_roles_tab

            settings.disable_secrets_manager

            Support::Waiter.wait_until(max_duration: 60, sleep_interval: 2) do
              !settings.has_secrets_manager_enabled?
            end

            expect(settings).not_to have_secrets_manager_enabled
          end
        end
      end
    end
  end
end
