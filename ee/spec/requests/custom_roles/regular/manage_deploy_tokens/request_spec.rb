# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with manage_deploy_tokens custom role', feature_category: :continuous_delivery do
  include ApiHelpers

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, namespace: group) }
  let_it_be_with_reload(:role) { create(:member_role, :guest, :manage_deploy_tokens, namespace: group) }

  before do
    stub_licensed_features(custom_roles: true)

    sign_in(user)
  end

  describe GroupsController do
    let_it_be(:membership) do
      create(:group_member, :guest, user: user, source: group, member_role: role)
    end

    it 'cannot update the group', :aggregate_failures do
      expect do
        put group_path(group), params: { group: { name: 'new-name' } }

        expect(response).to have_gitlab_http_status(:not_found)
      end.to not_change { group.reload.name }
    end
  end

  describe 'manage project deploy tokens' do
    let_it_be(:membership) do
      create(:project_member, :guest, user: user, source: project, member_role: role)
    end

    let_it_be(:deploy_token) { create(:deploy_token, projects: [project]) }

    describe Projects::Settings::RepositoryController do
      describe '#show' do
        it 'user has access via a custom role' do
          get project_settings_repository_path(project)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to have_text(s_('DeployTokens|Deploy tokens'))
        end
      end

      describe '#create_deploy_token' do
        it 'user has access via a custom role' do
          params = { deploy_token: { name: 'name', expires_at: 1.day.from_now.to_datetime.to_s, read_repository: '1' } }

          expect do
            post create_deploy_token_project_settings_repository_path(project, params: params, format: :json)
          end.to change { project.deploy_tokens.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)
          expect(response).to match_response_schema('public_api/v4/deploy_token')
        end
      end
    end

    describe Projects::DeployTokensController do
      describe '#revoke' do
        it 'user has access via a custom role' do
          expect do
            put revoke_project_deploy_token_path(project, deploy_token)
          end.to change { deploy_token.reload.revoked }.to(true)

          expect(response).to have_gitlab_http_status(:redirect)
          expect(response).to redirect_to(project_settings_repository_path(project, anchor: 'js-deploy-tokens'))
        end
      end
    end

    describe API::DeployTokens do
      let_it_be(:url) { "/projects/#{project.id}/deploy_tokens" }

      describe 'GET all tokens' do
        it 'user has access via a custom role' do
          get api(url, user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/deploy_tokens')
        end
      end

      describe 'GET a single token' do
        it 'user has access via a custom role' do
          get api("#{url}/#{deploy_token.id}", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/deploy_token')
        end
      end

      describe 'POST' do
        it 'user has access via a custom role' do
          expect do
            post api(url, user), params: { name: 'Foo', expires_at: 1.day.from_now, scopes: ['read_repository'] }
          end.to change { DeployToken.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)
          expect(response).to match_response_schema('public_api/v4/deploy_token')
        end
      end

      describe 'DELETE' do
        it 'user has access via a custom role' do
          expect do
            delete api("#{url}/#{deploy_token.id}", user)
          end.to change { DeployToken.count }.by(-1)

          expect(response).to have_gitlab_http_status(:no_content)
        end
      end
    end
  end

  describe 'manage group deploy tokens' do
    let_it_be(:membership) do
      create(:group_member, :guest, user: user, source: group, member_role: role)
    end

    let_it_be(:deploy_token) { create(:deploy_token, :group, groups: [group]) }

    describe Groups::Settings::RepositoryController do
      describe '#show' do
        it 'user has access via a custom role' do
          get group_settings_repository_path(group)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to have_text(s_('DeployTokens|Deploy tokens'))
        end
      end

      describe '#create_deploy_token' do
        it 'user has access via a custom role' do
          params = { deploy_token: { name: 'name', expires_at: 1.day.from_now.to_datetime.to_s, read_repository: '1' } }

          expect do
            post create_deploy_token_group_settings_repository_path(group, params: params, format: :json)
          end.to change { group.deploy_tokens.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)
          expect(response).to match_response_schema('public_api/v4/deploy_token')
        end
      end
    end

    describe Groups::DeployTokensController do
      describe '#revoke' do
        it 'user has access via a custom role' do
          expect do
            put revoke_group_deploy_token_path(group, deploy_token)
          end.to change { deploy_token.reload.revoked }.to(true)

          expect(response).to have_gitlab_http_status(:redirect)
          expect(response).to redirect_to(group_settings_repository_path(group, anchor: 'js-deploy-tokens'))
        end
      end
    end

    describe API::DeployTokens do
      let_it_be(:url) { "/groups/#{group.id}/deploy_tokens" }

      describe 'GET all tokens' do
        it 'user has access via a custom role' do
          get api(url, user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/deploy_tokens')
        end
      end

      describe 'GET a single token' do
        it 'user has access via a custom role' do
          get api("#{url}/#{deploy_token.id}", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/deploy_token')
        end
      end

      describe 'POST' do
        it 'user has access via a custom role' do
          expect do
            post api(url, user), params: { name: 'Foo', expires_at: 1.day.from_now, scopes: ['read_repository'] }
          end.to change { DeployToken.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)
          expect(response).to match_response_schema('public_api/v4/deploy_token')
        end
      end

      describe 'DELETE' do
        it 'user has access via a custom role' do
          expect do
            delete api("#{url}/#{deploy_token.id}", user)
          end.to change { DeployToken.count }.by(-1)

          expect(response).to have_gitlab_http_status(:no_content)
        end
      end
    end
  end
end
