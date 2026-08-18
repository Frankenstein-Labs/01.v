# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::DashboardController, feature_category: :vulnerability_management do
  let_it_be(:group)   { create(:group) }
  let_it_be(:project) { create(:project, :small_repo, :public, namespace: group) }
  let_it_be(:user)    { create(:user, developer_of: group) }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  include_context '"Security and compliance" permissions' do
    let(:valid_request) { get :index, params: { namespace_id: project.namespace, project_id: project } }

    before_request do
      sign_in(user)
    end
  end

  it_behaves_like SecurityDashboardsPermissions do
    let(:vulnerable) { project }

    let(:security_dashboard_action) do
      get :index, params: { namespace_id: project.namespace, project_id: project }
    end
  end

  describe 'GET #index' do
    render_views

    def show_security_dashboard(current_user = user)
      sign_in(current_user)
      get :index, params: { namespace_id: project.namespace, project_id: project }
    end

    context 'when project has no vulnerabilities' do
      it 'renders empty state' do
        show_security_dashboard

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:index)
        expect(response.body).to have_css('div#js-project-security-dashboard[data-has-vulnerabilities="false"]')
      end
    end

    context 'when project has vulnerabilities' do
      before do
        create(:vulnerability, project: project)
      end

      it 'renders dashboard with vulnerability metadata' do
        show_security_dashboard

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:index)
        expect(response.body).to have_css('div#js-project-security-dashboard[data-has-vulnerabilities="true"]')
      end
    end

    context 'when upgraded dashboard is available' do
      before do
        allow(controller).to receive(:can?).and_call_original
        allow(controller).to receive(:can?)
          .with(user, :access_advanced_vulnerability_management, project).and_return(true)
      end

      it_behaves_like 'tracks govern usage event', 'security_dashboard' do
        let(:request) { show_security_dashboard }
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'visit_upgraded_security_dashboard' }
        let(:category) { described_class.name }
        subject(:service_action) { show_security_dashboard }
      end

      it 'does not track visit_security_dashboard event' do
        expect { show_security_dashboard }.not_to trigger_internal_events('visit_security_dashboard')
      end
    end
  end
end
