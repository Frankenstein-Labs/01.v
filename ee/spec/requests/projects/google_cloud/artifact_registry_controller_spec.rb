# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::GoogleCloud::ArtifactRegistryController, feature_category: :container_registry do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :private) }

  before do
    sign_in(user) if user
    stub_saas_features(google_cloud_support: true)
  end

  shared_examples 'google artifact registry' do
    context 'when user has access to registry' do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like 'returning response status', :ok

      context 'when feature is unavailable' do
        before do
          stub_saas_features(google_cloud_support: false)
        end

        it_behaves_like 'returning response status', :not_found
      end
    end

    context 'when user does not have access to registry' do
      it_behaves_like 'returning response status', :not_found
    end

    context 'with a public project and anonymous user' do
      let(:user) { nil }

      before do
        project.update!(visibility: Gitlab::VisibilityLevel::PUBLIC)
      end

      it_behaves_like 'returning response status', :not_found
    end
  end

  describe 'GET #index' do
    subject do
      get project_google_cloud_artifact_registry_index_path(project)
    end

    it_behaves_like 'google artifact registry'
  end

  describe 'GET #show' do
    subject do
      get project_google_cloud_artifact_registry_image_path(project, {
        image: 'alpine@sha256:6a0657acfef760bd9e293361c9b558e98e7d740ed0dffca823d17098a4ffddf5',
        project: 'dev-package-container-96a3ff34',
        repository: 'myrepo',
        location: 'us-east1'
      })
    end

    it_behaves_like 'google artifact registry'
  end
end
