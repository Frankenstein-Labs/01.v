# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with read_admin_cicd', :enable_admin_mode, feature_category: :runner_core do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:permission) { :read_admin_cicd }
  let_it_be(:role) { create(:admin_member_role, permission, user: current_user) }

  before do
    stub_licensed_features(custom_roles: true, runner_performance_insights: true)
    sign_in(current_user)
  end

  describe Admin::RunnersController do
    describe "GET #index" do
      it 'user has access via a custom role' do
        get admin_runners_path

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:index)
      end
    end

    describe "GET #show" do
      it 'user has access via a custom role' do
        runner = create(:ci_runner)

        get admin_runner_path(runner.id)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:show)
      end
    end

    describe "GET #dashboard" do
      it 'user has access via a custom role' do
        get dashboard_admin_runners_path

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:dashboard)
      end
    end
  end

  describe Admin::JobsController do
    describe "GET #index" do
      it 'user has access via a custom role' do
        get admin_jobs_path

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:index)
      end
    end
  end

  describe Admin::DashboardController do
    describe "#index" do
      it 'user has access via a custom role' do
        get admin_root_path

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:index)
      end
    end
  end
end
