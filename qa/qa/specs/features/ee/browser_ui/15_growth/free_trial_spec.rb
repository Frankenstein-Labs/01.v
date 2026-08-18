# frozen_string_literal: true

module QA
  RSpec.describe 'Growth', :requires_admin, only: { subdomain: :staging }, feature_category: :acquisition do
    describe 'SaaS trials' do
      let(:api_client) { Runtime::API::Client.as_admin }
      let(:user) do
        create(:user, :hard_delete, email: "test-user-#{SecureRandom.hex(4)}@gitlab.com", api_client: api_client)
      end

      let(:group_for_trial) do
        Resource::Sandbox.fabricate! do |sandbox|
          sandbox.path = "test-group-fulfillment#{SecureRandom.hex(4)}"
          sandbox.api_client = api_client
        end
      end

      before do
        Flow::Login.sign_in(as: user)
        group_for_trial.visit!
      end

      after do
        group_for_trial.remove_via_api!
      end

      describe 'starts a free trial' do
        context 'when visiting trials page with multiple eligible namespaces' do
          let!(:group) do
            Resource::Sandbox.fabricate! do |sandbox|
              sandbox.path = "test-group-fulfillment#{SecureRandom.hex(4)}"
              sandbox.api_client = api_client
            end
          end

          before do
            Runtime::Browser.visit(:gitlab, EE::Page::Trials::New)
          end

          after do
            group.remove_via_api!
          end

          it(
            'registers for a new trial'
          ) do
            EE::Flow::Trial.register_for_trial(group: group_for_trial)

            Page::Group::Show.perform do |group|
              expect(group).to have_notice(%r{You have successfully started .*GitLab.* trial})
            end

            Page::Group::Menu.perform(&:go_to_billing)

            QA::EE::Page::Group::Settings::Billing.perform do |billing|
              expect do
                billing.free_trial_plan_billing_content
              end.to eventually_include('Your group is on a trial of GitLab Ultimate')
                       .within(max_duration: 120, max_attempts: 60, reload_page: page)
            end
          end
        end
      end
    end
  end
end
