# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::ComplianceDashboardsController, feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:user) { create(:user) }

  before_all do
    group.add_developer(user)
  end

  before do
    sign_in(user)
  end

  describe 'GET #show' do
    subject(:request) { get :show, params: { namespace_id: project.namespace, project_id: project } }

    render_views

    context 'when licensed and project is in a group' do
      before do
        stub_licensed_features(project_level_compliance_dashboard: true)
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_compliance_dashboard, project).and_return(true)
      end

      it 'renders the show template with HTTP 200', :aggregate_failures do
        request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('js-compliance-report')
      end
    end

    context 'when not licensed and project is in a group' do
      before do
        stub_licensed_features(project_level_compliance_dashboard: false)
      end

      it 'renders the unavailable template with HTTP 200', :aggregate_failures do
        request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('Compliance center is not available')
        expect(response.body).to include(
          'Track compliance across your projects. Upgrade to GitLab Ultimate to access the Compliance center.'
        )
      end
    end

    context 'when project is not in a group' do
      let_it_be(:personal_project) { create(:project) }

      subject(:request) do
        get :show, params: { namespace_id: personal_project.namespace, project_id: personal_project }
      end

      before_all do
        personal_project.add_developer(user)
      end

      before do
        stub_licensed_features(project_level_compliance_dashboard: true)
      end

      it 'renders the unavailable template with HTTP 200', :aggregate_failures do
        request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('Compliance center is not available')
        expect(response.body).to include(
          'The Compliance center is only available for projects that belong to a group with an Ultimate license.'
        )
      end
    end
  end
end
