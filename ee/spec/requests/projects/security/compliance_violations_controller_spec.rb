# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::ComplianceViolationsController, feature_category: :compliance_management do
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  describe 'GET #show' do
    subject(:request) { get project_security_compliance_violation_path(project, '123') }

    context 'when user is not authorized' do
      before do
        sign_in(user)
      end

      it 'returns 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is authorized' do
      let(:project_level_compliance_dashboard) { true }

      before do
        sign_in(user)
        stub_licensed_features(project_level_compliance_dashboard:)
      end

      shared_examples 'show action' do
        it 'renders the show template' do
          request

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to render_template(:show)
        end

        context 'when project_level_compliance_dashboard is not available' do
          let(:project_level_compliance_dashboard) { false }

          it 'returns 404' do
            request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context 'as owner' do
        before_all do
          project.add_owner(user)
        end

        it_behaves_like 'show action'
      end

      context 'as security manager' do
        before_all do
          project.add_security_manager(user)
        end

        it_behaves_like 'show action'
      end
    end
  end
end
