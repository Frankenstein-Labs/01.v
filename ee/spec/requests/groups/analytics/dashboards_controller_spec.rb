# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Analytics::DashboardsController, feature_category: :groups_and_projects do
  let_it_be(:group) { create(:group) }
  let_it_be(:another_group) { create(:group) }
  let_it_be(:user) do
    create(:user).tap do |user|
      group.add_reporter(user)
      another_group.add_reporter(user)
    end
  end

  shared_examples 'forbidden response' do
    it 'returns forbidden response' do
      request

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  shared_examples 'shared analytics value streams dashboard' do
    it 'passes data_source_clickhouse to data attributes' do
      request

      expect(response).to be_successful

      expect(js_list_app_attributes).to include('data-data-source-clickhouse')
    end

    it 'passes topics-explore-projects-path to data attributes' do
      request

      expect(response).to be_successful

      expect(js_list_app_attributes).to include('data-topics-explore-projects-path')
    end

    context 'when project_id outside of the group hierarchy was set' do
      it 'does not pass the project pointer' do
        project_outside_the_hierarchy = create(:project)
        analytics_dashboards_pointer.update_column(:target_project_id, project_outside_the_hierarchy.id)

        request

        expect(response).to be_successful

        expect(js_list_app_attributes).not_to include('data-dashboard-project')
      end
    end

    it 'does not pass pointer_project if the configured project is missing' do
      analytics_dashboards_pointer.target_project.destroy!
      request

      expect(response).to be_successful

      expect(js_list_app_attributes).not_to include('data-dashboard-project')
    end

    it 'does not pass pointer_project if it was not configured' do
      request

      expect(response).to be_successful

      expect(js_list_app_attributes).not_to include('data-dashboard-project')
    end
  end

  describe 'GET index' do
    let(:request) { get(group_analytics_dashboards_path(group)) }
    let_it_be_with_refind(:projects) { create_list(:project, 4, :public, group: group) }
    let(:analytics_dashboards_pointer) do
      create(:analytics_dashboards_pointer, namespace: group, target_project: projects.first)
    end

    before do
      stub_licensed_features(group_level_analytics_dashboard: true)
    end

    context 'when user is not logged in' do
      it 'redirects the user to the login page' do
        request

        expect(response).to redirect_to new_user_session_path
      end
    end

    context 'when user is logged in' do
      before do
        sign_in(user)
      end

      context 'when the license is not available' do
        before do
          stub_licensed_features(group_level_analytics_dashboard: false)
        end

        it_behaves_like 'forbidden response'
      end

      context 'when the license is available' do
        before do
          stub_licensed_features(group_level_analytics_dashboard: true)
        end

        it 'succeeds' do
          request

          expect(response).to be_successful
        end

        it_behaves_like 'shared analytics value streams dashboard'
      end
    end
  end

  describe 'GET value_streams_dashboard' do
    let(:request) { get(build_dashboard_path(group)) }

    context 'when user is not logged in' do
      before do
        stub_licensed_features(group_level_analytics_dashboard: true)
      end

      it 'redirects the user to the login page' do
        request

        expect(response).to redirect_to new_user_session_path
      end
    end

    context 'when user is not authorized' do
      let_it_be(:user) { create(:user) }

      before do
        stub_licensed_features(group_level_analytics_dashboard: true)

        sign_in(user)
      end

      it_behaves_like 'forbidden response'
    end

    context 'when user is logged in' do
      before do
        sign_in(user)
      end

      context 'when the license is not available' do
        before do
          stub_licensed_features(group_level_analytics_dashboard: false)
        end

        it_behaves_like 'forbidden response'
      end

      context 'when the license is available' do
        let_it_be(:subgroup) { create(:group, parent: group) }
        let_it_be_with_refind(:projects) { create_list(:project, 4, :public, group: group) }
        let_it_be(:subgroup_projects) { create_list(:project, 2, :public, group: subgroup) }
        let(:analytics_dashboards_pointer) do
          create(:analytics_dashboards_pointer, namespace: group, target_project: projects.first)
        end

        before do
          stub_licensed_features(group_level_analytics_dashboard: true)
        end

        it 'succeeds' do
          request

          expect(response).to be_successful
        end

        it_behaves_like 'shared analytics value streams dashboard'
      end
    end
  end

  def js_list_app_attributes
    Nokogiri::HTML.parse(response.body).at_css('div#js-analytics-dashboards-list-app').attributes
  end

  def build_dashboard_path(namespace)
    "#{group_analytics_dashboards_path(namespace)}/value_streams_dashboard"
  end
end
