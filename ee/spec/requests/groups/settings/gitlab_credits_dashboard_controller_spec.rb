# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::GitlabCreditsDashboardController, feature_category: :consumables_cost_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  before do
    sign_in(user)
  end

  describe 'GET /groups/*group_id/-/settings/gitlab_credits_dashboard' do
    subject(:request) { get group_settings_gitlab_credits_dashboard_index_path(group) }

    context 'when user is an owner' do
      before_all do
        group.add_owner(user)
      end

      context 'when in .com', :saas do
        before do
          stub_ee_application_setting(should_check_namespace_plan: true)

          allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |instance|
            allow(instance).to receive(:execute).and_return([Hashie::Mash.new(id: 1, code: ::Plan::PREMIUM)])
          end
        end

        it 'renders 404 for free group' do
          request

          expect(response).to have_gitlab_http_status(:not_found)
        end

        context 'when group has gitlab credits entitlement' do
          context 'when group is paid' do
            subject(:request) { get group_settings_gitlab_credits_dashboard_index_path(paid_group) }

            let_it_be_with_reload(:paid_group) { create(:group_with_plan, plan: :premium_plan) }

            before_all do
              paid_group.add_owner(user)
            end

            it 'returns 200' do
              request

              expect(response).to have_gitlab_http_status(:ok)
            end

            context 'for display_gitlab_credits_user_data' do
              before do
                paid_group.namespace_settings.update!(display_gitlab_credits_user_data: true)
              end

              it 'pushes the setting to the frontend' do
                request

                expect(response.body).to include('gon.display_gitlab_credits_user_data=true')
              end
            end

            it 'pushes wallet_agnostic_credits_dashboard feature flag to the frontend' do
              request

              expect(response.body).to include('"walletAgnosticCreditsDashboard":true')
            end
          end

          context 'when group only has a gitlab_credits add-on' do
            before do
              create(:gitlab_subscription_add_on_purchase, :gitlab_credits, :active, namespace: group)
            end

            it 'returns 200' do
              request

              expect(response).to have_gitlab_http_status(:ok)
            end
          end
        end
      end

      context 'when in Self-Managed' do
        it 'renders 404' do
          request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when user is not an owner', :saas do
      subject(:request) { get group_settings_gitlab_credits_dashboard_index_path(paid_group) }

      let_it_be_with_reload(:paid_group) { create(:group_with_plan, plan: :premium_plan) }

      before_all do
        paid_group.add_maintainer(user)
      end

      before do
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      it 'returns 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
