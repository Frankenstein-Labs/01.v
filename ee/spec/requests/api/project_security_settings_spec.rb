# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProjectSecuritySettings, :aggregate_failures, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:security_setting) { create(:project_security_setting, project: project) }
  let(:url) { "/projects/#{project.id}/security_settings" }

  describe 'GET /projects/:id/security_settings' do
    context 'when user is not authenticated' do
      it 'returns 401 Unauthorized' do
        get api(url)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when user is authenticated' do
      before do
        stub_licensed_features(secret_push_protection: true)
      end

      it 'returns project security settings when the user has Security Manager role' do
        project.add_security_manager(user)
        get api(url, user)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'returns project security settings when the user has at least the Developer role' do
        project.add_developer(user)
        get api(url, user)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'returns 401 Unauthorized when the user has Guest role' do
        project.add_guest(user)
        get api(url, user)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it 'returns 404 for non-existing project' do
        project.add_developer(user)
        get api("/projects/non-existing/security_settings", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it_behaves_like 'authorizing granular token permissions', :read_security_setting do
        let(:boundary_object) { project }
        let(:request) { get api(url, personal_access_token: pat) }

        before do
          project.add_developer(user)
        end
      end
    end
  end

  describe 'PUT /projects/:id/security_settings' do
    context 'when user is not authenticated' do
      it 'returns 401 Unauthorized' do
        put api(url)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when user is authenticated' do
      before do
        stub_licensed_features(secret_push_protection: true)
      end

      shared_examples 'successful setting update' do |role|
        before do
          project.send(:"add_#{role}", user)
        end

        it 'updates project security settings using the secret_push_protection_enabled param' do
          put api(url, user), params: { secret_push_protection_enabled: true }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['secret_push_protection_enabled']).to be(true)
        end

        it 'updates project security settings using the pre_receive_secret_detection_enabled param' do
          put api(url, user), params: { pre_receive_secret_detection_enabled: true }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['secret_push_protection_enabled']).to be(true)
        end

        context 'when secret push protection is enforced at instance-level' do
          before do
            Gitlab::CurrentSettings.update!(secret_push_protection_enforced: true)
          end

          it 'returns 403 Forbidden when trying to disable secret push protection' do
            put api(url, user), params: { secret_push_protection_enabled: false }

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end

        it_behaves_like 'authorizing granular token permissions', :update_security_setting do
          let(:boundary_object) { project }
          let(:request) do
            put api(url, personal_access_token: pat), params: { secret_push_protection_enabled: true }
          end
        end

        context 'when project is archived' do
          before do
            project.update!(archived: true)
          end

          it 'returns 403 forbidden' do
            put api(url, user), params: { secret_push_protection_enabled: true }

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end

        context 'when projects group is archived' do
          let(:group) { create(:group, :archived) }
          let(:project) { create(:project, group: group) }

          before do
            project.add_maintainer(user)
          end

          it 'returns 403 forbidden' do
            put api(url, user), params: { secret_push_protection_enabled: true }

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end
      end

      it_behaves_like 'successful setting update', :maintainer
      it_behaves_like 'successful setting update', :security_manager

      context 'when the user is a Developer' do
        before do
          project.add_developer(user)
          stub_licensed_features(secret_push_protection: true)
        end

        it 'returns 401 Unauthorized for users with Developer role' do
          put api(url, user), params: { secret_push_protection_enabled: true }

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end
    end
  end

  describe 'PUT /projects/:id/security_settings with fast_dependency_paths_enabled' do
    before do
      stub_licensed_features(dependency_scanning: true)
      project.add_maintainer(user)
    end

    it 'updates fast_dependency_paths_enabled to true' do
      put api(url, user), params: { fast_dependency_paths_enabled: true }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['fast_dependency_paths_enabled']).to be(true)
    end

    it 'updates fast_dependency_paths_enabled to false' do
      project.security_setting.update!(fast_dependency_paths_enabled: true)

      put api(url, user), params: { fast_dependency_paths_enabled: false }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['fast_dependency_paths_enabled']).to be(false)
    end

    it 'returns 400 when no recognised param is provided' do
      put api(url, user), params: {}

      expect(response).to have_gitlab_http_status(:bad_request)
    end

    context 'when only dependency_scanning license is available (not secret_push_protection)' do
      before do
        stub_licensed_features(secret_push_protection: false, dependency_scanning: true)
      end

      it 'allows updating fast_dependency_paths_enabled' do
        put api(url, user), params: { fast_dependency_paths_enabled: true }

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'returns 403 Forbidden when trying to update secret_push_protection_enabled' do
        put api(url, user), params: { secret_push_protection_enabled: true }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when neither license is available' do
      before do
        stub_licensed_features(secret_push_protection: false, dependency_scanning: false)
      end

      it 'returns 403 Forbidden' do
        put api(url, user), params: { fast_dependency_paths_enabled: true }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'license and visibility checks' do
    context 'with Ultimate license' do
      before do
        project.add_developer(user)
        stub_licensed_features(secret_push_protection: true)
      end

      it 'allows access for public project' do
        get api(url, user)
        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'allows access for private project' do
        project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)

        get api(url, user)
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'without Ultimate license' do
      before do
        project.add_developer(user)
        stub_licensed_features(secret_push_protection: false)
      end

      it 'returns 403 Forbidden' do
        get api(url, user)
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
