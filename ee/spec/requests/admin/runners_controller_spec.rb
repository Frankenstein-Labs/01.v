# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::RunnersController, :enable_admin_mode, feature_category: :fleet_visibility do
  let_it_be_with_refind(:user) { create(:user) }
  let_it_be(:runner) { create(:ci_runner) }

  subject { response }

  before do
    stub_licensed_features(custom_roles: true, runner_performance_insights: true)

    sign_in(user)
  end

  describe 'GET #edit' do
    before do
      get edit_admin_runner_path(runner)
    end

    context 'with a non-admin user' do
      it { is_expected.to have_gitlab_http_status(:not_found) }
    end
  end

  shared_examples 'accessible when user has read_admin_cicd ability through a custom role' do
    context 'when user has read_admin_cicd ability through a custom role' do
      let_it_be_with_refind(:role) { create(:admin_member_role, :read_admin_cicd, user: user) }

      it { is_expected.to have_gitlab_http_status(:ok) }
    end
  end

  describe 'GET #index' do
    before do
      get admin_runners_path
    end

    context 'with a non-admin user' do
      it { is_expected.to have_gitlab_http_status(:not_found) }

      it_behaves_like 'accessible when user has read_admin_cicd ability through a custom role'
    end
  end

  describe 'GET #show' do
    before do
      get admin_runner_path(runner)
    end

    context 'with a non-admin user' do
      it { is_expected.to have_gitlab_http_status(:not_found) }

      it_behaves_like 'accessible when user has read_admin_cicd ability through a custom role'
    end
  end

  describe 'GET #dashboard' do
    before do
      get dashboard_admin_runners_path
    end

    context 'with a non-admin user' do
      it { is_expected.to have_gitlab_http_status(:not_found) }

      it_behaves_like 'accessible when user has read_admin_cicd ability through a custom role'
    end
  end
end
