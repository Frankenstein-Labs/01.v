# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'view compliance dashboard', feature_category: :compliance_management do
  describe 'GET /:group/:project/-/security/compliance_dashboard' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:user) { create(:user, :with_namespace) }

    before do
      stub_licensed_features(project_level_compliance_dashboard: true)

      login_as(user)
    end

    shared_examples 'compliance dashboard access' do
      it 'returns 200 response' do
        get project_security_compliance_dashboard_path(project)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when user has access' do
      context 'as owner' do
        before_all do
          project.add_owner(user)
        end

        it_behaves_like 'compliance dashboard access'
      end

      context 'as security manager' do
        before_all do
          project.add_security_manager(user)
        end

        it_behaves_like 'compliance dashboard access'
      end
    end

    context 'when user has no access' do
      it 'returns 404 response' do
        get project_security_compliance_dashboard_path(project)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
