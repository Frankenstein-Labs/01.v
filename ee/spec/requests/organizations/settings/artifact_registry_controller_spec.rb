# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::Settings::ArtifactRegistryController, feature_category: :artifact_registry do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:member) { create(:user) }
  let_it_be(:non_member) { create(:user) }

  let(:settings_path) { artifact_registry_settings_organization_path(organization) }

  let(:expected_app_data) do
    {
      'organization_gid' => organization.to_global_id.to_s,
      'client_base_url' => 'https://artifact-registry.example.com'
    }
  end

  before_all do
    create(:organization_owner, organization: organization, user: owner)
    create(:organization_user, organization: organization, user: member)
  end

  before do
    stub_config(artifact_registry: { api_url: 'https://artifact-registry.example.com/api/v1' })
  end

  subject(:perform_request) { get settings_path }

  def mount_element
    Nokogiri::HTML.parse(response.body).at_css('#js-artifact-registry-settings')
  end

  shared_examples 'a hidden settings mount' do
    it 'returns not found and does not render the mount', :aggregate_failures do
      perform_request

      expect(response).to have_gitlab_http_status(:not_found)
      expect(mount_element).to be_nil
    end
  end

  describe 'GET #show' do
    it 'declares the artifact_registry feature category' do
      expect(described_class.feature_category_for_action(:show))
        .to eq(:artifact_registry)
    end

    context 'when the user is an organization owner' do
      before do
        sign_in(owner)
      end

      it 'serves the settings mount carrying the organization GID and the client base URL',
        :aggregate_failures do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(mount_element).to be_present
        expect(Gitlab::Json::SafeParser.parse(mount_element['data-app-data'])).to eq(expected_app_data)
      end

      context 'when the artifact_registry_ui feature flag is disabled' do
        before do
          stub_feature_flags(artifact_registry_ui: false)
        end

        it_behaves_like 'a hidden settings mount'
      end

      context 'when ui_for_organizations is disabled', :ui_for_organizations_disabled do
        it_behaves_like 'a hidden settings mount'
      end
    end

    context 'when the user is a member holding only the read ability' do
      before do
        sign_in(member)
      end

      it_behaves_like 'a hidden settings mount'
    end

    context 'when the user cannot read the registry' do
      before do
        sign_in(non_member)
      end

      it_behaves_like 'a hidden settings mount'
    end

    context 'when the user is not signed in' do
      it 'redirects to the sign in page' do
        perform_request

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
