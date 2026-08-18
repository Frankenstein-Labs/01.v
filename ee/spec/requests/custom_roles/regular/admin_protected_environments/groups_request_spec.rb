# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with admin_protected_environments custom role', feature_category: :continuous_delivery do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:protected_environment) { create(:protected_environment, :production, :group_level, group: group) }

  shared_context 'with protected environment setting' do |enabled|
    let_it_be(:role) do
      create(:member_role, :guest, namespace: group, admin_protected_environments: enabled)
    end

    let_it_be(:group_member) do
      create(:group_member, :guest, member_role: role, user: user, group: group)
    end
  end

  before do
    stub_licensed_features(custom_roles: true)
    sign_in(user)
  end

  describe Groups::Settings::CiCdController do
    let(:settings_page_path) { group_settings_ci_cd_path(group) }
    let(:update_params) { { group: { max_artifacts_size: 100 } } }

    context 'when user has protected environment access' do
      include_context 'with protected environment setting', true

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

        it 'prevents modification of CI/CD settings' do
          update_settings

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when user lacks protected environment access' do
      include_context 'with protected environment setting', false

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

  describe Groups::ProtectedEnvironmentsController do
    let_it_be(:group) { create(:group) }
    let_it_be(:protected_environment) { create(:protected_environment, :group_level, group: group, name: 'production') }

    let(:environment_params) do
      {
        protected_environment: {
          name: 'staging',
          deploy_access_levels_attributes: [{ group_id: group.id }]
        }
      }
    end

    let(:base_path) { group_protected_environments_path(group) }
    let(:environment_path) { group_protected_environment_path(group, protected_environment) }
    let(:settings_redirect) { group_settings_ci_cd_path(group, anchor: 'js-protected-environments-settings') }

    context 'when user has protected environment access' do
      include_context 'with protected environment setting', true

      describe '#POST create' do
        subject(:create_environment) { post base_path, params: environment_params, as: :json }

        it 'creates a new protected environment' do
          expect { create_environment }.to change { ProtectedEnvironment.count }

          expect(response).to have_gitlab_http_status(:found)
          expect(flash[:notice]).to eq('Your environment has been protected.')
          expect(response).to redirect_to(settings_redirect)
        end
      end

      describe '#PUT update' do
        let(:update_params) do
          {
            protected_environment: {
              name: protected_environment.name,
              deploy_access_levels_attributes: [
                { id: protected_environment.deploy_access_levels.first.id, group_id: group.id }
              ]
            }
          }
        end

        subject(:update_environment) { put environment_path, params: update_params }

        it 'updates the protected environment' do
          expect { update_environment }
            .not_to change { protected_environment.reload.name }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      describe '#DELETE destroy' do
        let_it_be(:deletable_environment) do
          create(:protected_environment, :group_level,
            group: group,
            name: 'testing'
          )
        end

        subject(:delete_environment) { delete group_protected_environment_path(group, deletable_environment) }

        it 'removes the protected environment' do
          expect { delete_environment }.to change { ProtectedEnvironment.count }

          expect(response).to have_gitlab_http_status(:found)
          expect(flash[:notice]).to eq('Your environment has been unprotected')
          expect(response).to redirect_to(settings_redirect)
        end
      end
    end

    context 'when user lacks protected environment access' do
      include_context 'with protected environment setting', false

      describe '#POST create' do
        subject(:create_environment) { post base_path, params: environment_params, as: :json }

        it 'denies environment creation' do
          expect { create_environment }.not_to change { ProtectedEnvironment.count }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      describe '#PUT update' do
        let(:update_params) do
          {
            protected_environment: {
              name: protected_environment.name,
              deploy_access_levels_attributes: [
                { id: protected_environment.deploy_access_levels.first.id, group_id: group.id }
              ]
            }
          }
        end

        subject(:update_environment) { put environment_path, params: update_params }

        it 'denies environment update' do
          update_environment

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      describe '#DELETE destroy' do
        let_it_be(:deletable_environment) do
          create(:protected_environment, :group_level,
            group: group,
            name: 'testing'
          )
        end

        subject(:delete_environment) { delete group_protected_environment_path(group, deletable_environment) }

        it 'denies environment deletion' do
          expect { delete_environment }.not_to change { ProtectedEnvironment.count }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
