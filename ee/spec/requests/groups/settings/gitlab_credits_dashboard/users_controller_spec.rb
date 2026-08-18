# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::GitlabCreditsDashboard::UsersController, feature_category: :consumables_cost_management do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }

  let(:display_gitlab_credits_user_data) { true }

  before do
    sign_in(user)
  end

  describe 'GET /groups/*group_id/-/settings/gitlab_credits_dashboard/users/:username' do
    subject(:request) { get group_settings_gitlab_credits_dashboard_user_path(group, username: user) }

    context 'when user is an owner' do
      before_all do
        group.add_owner(user)
      end

      context 'when in .com', :saas do
        before do
          stub_ee_application_setting(should_check_namespace_plan: true)
        end

        it 'renders 404 for free group' do
          request

          expect(response).to have_gitlab_http_status(:not_found)
        end

        context 'when group has gitlab credits entitlement' do
          context 'when group is paid' do
            subject(:request) { get group_settings_gitlab_credits_dashboard_user_path(paid_group, username: user) }

            let_it_be_with_reload(:paid_group) { create(:group_with_plan, plan: :premium_plan) }

            before_all do
              paid_group.add_owner(user)
            end

            before do
              paid_group.namespace_settings.update!(display_gitlab_credits_user_data: display_gitlab_credits_user_data)
            end

            it 'returns 200' do
              request

              expect(response).to have_gitlab_http_status(:ok)
            end

            it 'pushes wallet_agnostic_credits_dashboard feature flag to the frontend' do
              request

              expect(response.body).to have_pushed_frontend_feature_flags(walletAgnosticCreditsDashboard: true)
            end

            context 'when display_gitlab_credits_user_data is false' do
              let(:display_gitlab_credits_user_data) { false }

              it 'renders 404' do
                request

                expect(response).to have_gitlab_http_status(:not_found)
              end
            end
          end

          context 'when group only has a gitlab_credits add-on' do
            before do
              group.namespace_settings.update!(display_gitlab_credits_user_data: display_gitlab_credits_user_data)
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
      subject(:request) { get group_settings_gitlab_credits_dashboard_user_path(paid_group, username: user) }

      let_it_be_with_reload(:paid_group) { create(:group_with_plan, plan: :premium_plan) }

      before_all do
        paid_group.add_maintainer(user)
      end

      before do
        paid_group.namespace_settings.update!(display_gitlab_credits_user_data: display_gitlab_credits_user_data)
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      it 'returns 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
