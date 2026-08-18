# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::DastScannerProfilesController, type: :request, feature_category: :dynamic_application_security_testing do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:dast_scanner_profile) { create(:dast_scanner_profile, project: project) }

  shared_context 'on-demand scans feature available' do
    before do
      stub_licensed_features(security_on_demand_scans: true)
    end
  end

  shared_context 'user authorized' do
    before_all do
      project.add_developer(user)
    end

    before do
      login_as(user)
    end
  end

  shared_examples 'a GET request' do
    include_context '"Security and compliance" permissions' do
      let(:valid_request) { get path }

      before_request do
        project.add_developer(user)
        login_as(user)
      end
    end

    context 'feature available' do
      include_context 'on-demand scans feature available'

      context 'user authorized' do
        include_context 'user authorized'

        it 'can access page' do
          get path

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'user not authorized' do
        before_all do
          project.add_guest(user)
        end

        before do
          login_as(user)
        end

        it 'sees a 404 error' do
          get path

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'feature not available' do
      include_context 'user authorized'

      it 'sees a 404 error' do
        stub_licensed_features(security_on_demand_scans: false)
        get path

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET #new' do
    it_behaves_like 'a GET request' do
      let(:path) { new_project_security_configuration_profile_library_dast_scanner_profile_path(project) }
    end
  end

  describe 'GET #edit' do
    include_context 'user authorized'
    include_context 'on-demand scans feature available'

    let(:edit_path) { edit_project_security_configuration_profile_library_dast_scanner_profile_path(project, dast_scanner_profile) }

    it_behaves_like 'a GET request' do
      let(:path) { edit_path }
    end

    it 'sets scanner_profile' do
      get edit_path
      expect(assigns(:scanner_profile)).to eq(dast_scanner_profile)
    end

    context 'record does not exist' do
      let(:dast_scanner_profile) { 0 }

      it 'sees a 404 error' do
        get edit_path

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'can not edit scan' do
      let_it_be_with_reload(:project) { create(:project, :repository, developers: user) }
      let_it_be(:protected_branch) { create(:protected_branch, authorize_user_to_push: nil, authorize_user_to_merge: nil, project: project, name: 'master') }
      let_it_be(:dast_profile) { create(:dast_profile, project: project, branch_name: protected_branch.name) }
      let_it_be(:dast_scanner_profile) { dast_profile.dast_scanner_profile }

      before do
        login_as(user)
      end

      it 'sees a 403 error' do
        get edit_path

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
