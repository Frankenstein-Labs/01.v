# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organizations::ArtifactRegistryRepositoriesController', feature_category: :artifact_registry do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:member) { create(:user) }
  let_it_be(:non_member) { create(:user) }

  let(:slug) { Organizations::ArtifactRegistry::STUB_SLUG }
  let(:repositories_base_path) { "/o/#{organization.path}/-/artifact_registry/#{slug}/repositories" }

  # The mount anchors the SPA router to the base path built from the validated
  # stub slug, not from the request path, so the app data is identical on the
  # top route and any catch-all sub-path: a sub-path serves the same app.
  #
  # The test environment configures `api_url` as a bare origin, so the client base URL
  # the view emits is that value unchanged; the derivation itself is covered in
  # ee/spec/helpers/organizations/artifact_registry_helper_spec.rb.
  let(:expected_app_data) do
    {
      'organization_gid' => organization.to_global_id.to_s,
      'slug' => slug,
      'base_path' => repositories_base_path,
      'client_base_url' => Gitlab.config.artifact_registry['api_url']
    }
  end

  before_all do
    create(:organization_user, organization: organization, user: member)
  end

  subject(:perform_request) { get path }

  def mount_element
    Nokogiri::HTML.parse(response.body).at_css('#js-artifact-registry-repositories')
  end

  shared_examples 'a hidden repositories mount' do
    it 'returns not found and does not render the mount', :aggregate_failures do
      perform_request

      expect(response).to have_gitlab_http_status(:not_found)
      expect(mount_element).to be_nil
    end
  end

  shared_examples 'the gated repositories mount' do
    context 'when the feature flag is enabled and the user can read the registry' do
      before do
        sign_in(member)
      end

      it 'serves the repositories mount carrying the organization GID, slug, base path, ' \
        'and client base URL', :aggregate_failures do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(mount_element).to be_present
        expect(Gitlab::Json::SafeParser.parse(mount_element['data-app-data'])).to eq(expected_app_data)
      end

      context 'when the slug is not the stub slug' do
        let(:slug) { "not-#{Organizations::ArtifactRegistry::STUB_SLUG}" }

        it_behaves_like 'a hidden repositories mount'
      end

      context 'when the artifact_registry_ui feature flag is disabled' do
        before do
          stub_feature_flags(artifact_registry_ui: false)
        end

        it_behaves_like 'a hidden repositories mount'
      end

      context 'when ui_for_organizations is disabled', :ui_for_organizations_disabled do
        it_behaves_like 'a hidden repositories mount'
      end
    end

    context 'when the user cannot read the registry' do
      before do
        sign_in(non_member)
      end

      it_behaves_like 'a hidden repositories mount'
    end

    context 'when the user is not signed in' do
      it 'redirects to the sign in page' do
        perform_request

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET #index' do
    it 'declares the artifact_registry feature category' do
      expect(Organizations::ArtifactRegistryRepositoriesController.feature_category_for_action(:index))
        .to eq(:artifact_registry)
    end

    context 'on the repositories base path' do
      let(:path) { repositories_base_path }

      it_behaves_like 'the gated repositories mount'
    end

    context 'on a deep catch-all sub-path (hard reload or direct deep link)' do
      let(:path) { "#{repositories_base_path}/some/deep/link" }

      it_behaves_like 'the gated repositories mount'
    end
  end
end
