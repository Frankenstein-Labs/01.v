# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Profiles::GitlabCreditsDashboardController, :saas, feature_category: :consumables_cost_management do
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be_with_reload(:group) { create(:group_with_plan, plan: :premium_plan) }

  before do
    stub_ee_application_setting(should_check_namespace_plan: true)
    sign_in(user)
  end

  # The resolved group is the user's default GitLab Duo namespace. The candidate
  # resolution is covered by UserPreference specs, so here we stub the resolved
  # namespace to exercise the controller's authorization and scoping logic.
  def set_duo_default_namespace(namespace)
    # rubocop:disable RSpec/AnyInstanceOf -- request reloads current_user; stubbing the resolved namespace keeps the test focused on controller logic
    allow_any_instance_of(UserPreference)
      .to receive(:duo_default_namespace_with_fallback).and_return(namespace)
    # rubocop:enable RSpec/AnyInstanceOf
  end

  describe 'GET /-/profile/gitlab_credits_dashboard' do
    subject(:request) { get profile_gitlab_credits_dashboard_index_path }

    context 'when the default Duo namespace is an entitled root group' do
      before do
        set_duo_default_namespace(group)
      end

      it 'returns 200 and renders the dashboard scoped to that namespace', :aggregate_failures do
        request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('js-user-gitlab-credits-dashboard')
        expect(response.body).to include(group.full_path)
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(user_gitlab_credits_dashboard: false)
        end

        it 'returns 404' do
          request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when not on .com' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'returns 404' do
          request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when the group is entitled via a gitlab_credits add-on' do
      let_it_be_with_reload(:group) { create(:group) }

      before do
        create(:gitlab_subscription_add_on_purchase, :gitlab_credits, :active, namespace: group)
        set_duo_default_namespace(group)
      end

      it 'returns 200' do
        request

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when there is no default Duo namespace' do
      before do
        set_duo_default_namespace(nil)
      end

      it 'returns 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the default Duo namespace is not entitled to gitlab credits' do
      let_it_be_with_reload(:group) { create(:group) }

      before do
        set_duo_default_namespace(group)
      end

      it 'returns 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
