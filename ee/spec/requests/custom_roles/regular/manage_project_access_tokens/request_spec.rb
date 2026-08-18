# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with manage_project_access_tokens custom role', feature_category: :system_access do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, :in_group) }

  before do
    stub_licensed_features(custom_roles: true)
    sign_in(user)
  end

  describe Projects::Settings::AccessTokensController do
    let_it_be(:role) { create(:member_role, :guest, namespace: project.group, manage_project_access_tokens: true) }
    let_it_be(:member) { create(:project_member, :guest, member_role: role, user: user, project: project) }

    describe 'GET /:namespace/:project/-/settings/access_tokens' do
      it 'user has access via custom role' do
        get project_settings_access_tokens_path(project)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:index)
      end
    end

    describe 'POST /:namespace/:project/-/settings/access_tokens' do
      let(:access_token_params) { { name: 'Nerd bot', scopes: ["api"], expires_at: 1.month.from_now } }

      subject(:submit_form) do
        post project_settings_access_tokens_path(project), params: { resource_access_token: access_token_params }
        response
      end

      context 'with custom access level same as the current user' do
        let(:access_token_params) do
          { name: 'Nerd bot', scopes: ["api"], expires_at: 1.month.from_now, access_level: 10 }
        end

        let(:resource) { project }

        it_behaves_like 'POST resource access tokens available'
      end

      context 'with custom access level higher than the current user' do
        let(:access_token_params) do
          { name: 'Nerd bot', scopes: ["api"], expires_at: 1.month.from_now, access_level: 20 }
        end

        let(:resource) { project }

        it 'renders JSON with an error' do
          submit_form

          parsed_body = Gitlab::Json.parse(response.body)
          expect(parsed_body['new_token']).to be_blank
          expect(parsed_body['errors']).to contain_exactly("Access level of the token contains permissions not\
 held by the creating user")
          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end
    end

    describe ProjectsController do
      it 'user has access via custom role' do
        get project_path(project)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('Access token')
      end
    end
  end
end
