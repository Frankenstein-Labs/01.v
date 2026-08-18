# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with admin_protected_environments custom role', feature_category: :continuous_delivery do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:protected_environment) { create(:protected_environment, project: project) }

  before do
    stub_licensed_features(custom_roles: true)
    sign_in(user)
  end

  shared_context 'with protected environment value' do |env|
    let_it_be(:role) { create(:member_role, :guest, namespace: group, admin_protected_environments: env) }
    let_it_be(:member) { create(:project_member, :guest, member_role: role, user: user, project: project) }
  end

  describe Projects::Settings::CiCdController do
    let(:settings_page_path) { project_settings_ci_cd_path(project) }
    let(:update_params) { { project: { ci_cd_settings: { build_timeout_human_readable: '1 hour' } } } }

    context 'when user has protected environment access' do
      include_context 'with protected environment value', true

      describe '#GET show' do
        subject(:view_settings_page) { get settings_page_path }

        it 'displays the CI/CD settings page successfully' do
          view_settings_page

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to include('CI/CD Settings')
        end
      end

      describe '#PUT update' do
        subject(:update_settings) { put settings_page_path, params: update_params }

        it 'allows modification of CI/CD settings' do
          update_settings

          expect(response).to redirect_to(project_settings_ci_cd_path(project))
        end
      end
    end

    context 'when user lacks protected environment access' do
      include_context 'with protected environment value', false

      describe '#GET show' do
        subject(:view_settings_page) { get settings_page_path }

        it 'denies access to the CI/CD settings page' do
          view_settings_page

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      describe '#PUT update' do
        subject(:update_settings) { put settings_page_path, params: update_params }

        it 'prevents modification of CI/CD settings' do
          update_settings

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  describe Projects::ProtectedEnvironmentsController do
    let(:environment_params) do
      {
        name: 'testenv',
        deploy_access_levels_attributes: [
          { access_level: Gitlab::Access::DEVELOPER }
        ]
      }
    end

    let(:base_path) { project_protected_environments_path(project) }
    let(:environment_path) { project_protected_environment_path(project, protected_environment) }
    let(:search_path) { search_project_protected_environments_path(project) }

    context 'when user has protected environment access' do
      include_context 'with protected environment value', true

      describe '#POST create' do
        subject(:create_environment) { post base_path, params: { protected_environment: environment_params } }

        it 'creates a new protected environment' do
          create_environment

          expect(response).to have_gitlab_http_status(:found)
          expect(flash[:notice]).to eq('Your environment has been protected.')
        end
      end

      describe '#PUT update' do
        subject(:update_environment) { put environment_path, params: { protected_environment: environment_params } }

        it 'updates the protected environment' do
          update_environment

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      describe '#DELETE destroy' do
        subject(:delete_environment) { delete environment_path }

        it 'removes the protected environment' do
          delete_environment

          expect(response).to have_gitlab_http_status(:found)
          expect(flash[:notice]).to eq('Your environment has been unprotected')
        end
      end

      describe '#GET search' do
        subject(:search_environments) { get search_path, params: { query: 'prod' } }

        it 'performs environment search' do
          search_environments

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'when user lacks protected environment access' do
      include_context 'with protected environment value', false

      describe '#POST create' do
        subject(:create_environment) { post base_path, params: { protected_environment: environment_params } }

        it 'denies environment creation' do
          create_environment

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      describe '#PUT update' do
        subject(:update_environment) { put environment_path, params: { protected_environment: environment_params } }

        it 'denies environment update' do
          update_environment

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      describe '#DELETE destroy' do
        subject(:delete_environment) { delete environment_path }

        it 'denies environment deletion' do
          delete_environment

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      describe '#GET search' do
        subject(:search_environments) { get search_path, params: { query: 'prod' } }

        it 'denies environment search' do
          search_environments

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
