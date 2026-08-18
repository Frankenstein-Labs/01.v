# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::ArtifactRegistryController, feature_category: :artifact_registry do
  let_it_be(:organization) { create(:organization) }

  # The test environment configures `api_url` as a bare origin, so the client base URL
  # the view emits is that value unchanged; the derivation itself is covered in
  # ee/spec/helpers/organizations/artifact_registry_helper_spec.rb.
  let(:expected_app_data) do
    {
      'organization_gid' => organization.to_global_id.to_s,
      'organization_path' => organization.path,
      'client_base_url' => Gitlab.config.artifact_registry['api_url']
    }
  end

  def mount_element
    Nokogiri::HTML.parse(response.body).at_css('#js-artifact-registry-setup')
  end

  shared_examples 'a rendered setup mount' do
    it 'renders the mount with the setup app data', :aggregate_failures do
      gitlab_request

      expect(response).to have_gitlab_http_status(:ok)
      expect(mount_element).to be_present
      expect(Gitlab::Json::SafeParser.parse(mount_element['data-app-data'])).to eq(expected_app_data)
    end
  end

  shared_examples 'a hidden setup mount' do
    it 'returns not found and does not render the mount', :aggregate_failures do
      gitlab_request

      expect(response).to have_gitlab_http_status(:not_found)
      expect(mount_element).to be_nil
    end
  end

  it 'declares the artifact_registry feature category for #index' do
    expect(described_class.feature_category_for_action('index')).to eq(:artifact_registry)
  end

  describe 'GET #index' do
    subject(:gitlab_request) { get artifact_registry_organization_index_path(organization) }

    context 'when the user is not signed in' do
      it_behaves_like 'organization - redirects to sign in page'

      context 'when `ui_for_organizations` feature flag is disabled' do
        before do
          stub_feature_flags(ui_for_organizations: false)
        end

        it_behaves_like 'organization - redirects to sign in page'
      end
    end

    context 'when the user is signed in' do
      let_it_be(:user) { create(:user) }

      before do
        sign_in(user)
      end

      context 'with no association to the organization' do
        it_behaves_like 'a hidden setup mount'
        it_behaves_like 'organization - action disabled by ui_for_organizations_enabled?'
      end

      context 'as an admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }

        it_behaves_like 'organization - successful response'
        it_behaves_like 'organization - action disabled by ui_for_organizations_enabled?'

        it_behaves_like 'a rendered setup mount'
      end

      context 'as a default organization user' do
        before_all do
          create(:organization_user, organization: organization, user: user)
        end

        # The flag-off case is not repeated here. A member is refused on every path - flag on
        # by the update-ability check, flag off by the gating concern - so a nested flag-off
        # context could not fail. The owner context below is where the flag is observable.
        it_behaves_like 'a hidden setup mount'
        it_behaves_like 'organization - action disabled by ui_for_organizations_enabled?'
      end

      context 'as an owner of an organization' do
        before_all do
          create(:organization_user, :owner, organization: organization, user: user)
        end

        it_behaves_like 'organization - successful response'
        it_behaves_like 'organization - action disabled by ui_for_organizations_enabled?'

        it_behaves_like 'a rendered setup mount'

        context 'when the `artifact_registry_ui` feature flag is disabled' do
          before do
            stub_feature_flags(artifact_registry_ui: false)
          end

          it_behaves_like 'a hidden setup mount'
        end
      end
    end
  end
end
