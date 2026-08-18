# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IdeController, feature_category: :web_ide do
  include ContentSecurityPolicyHelpers

  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)
  end

  it 'adds CSP headers for code suggestions' do
    get '/-/ide'

    expect(find_csp_directive('connect-src')).to include("https://cloud.gitlab.com/ai/")
  end

  context 'when SSO is enforced' do
    let(:saml_provider) { create(:saml_provider, enabled: true, enforced_sso: true) }
    let(:identity) { create(:group_saml_identity, saml_provider: saml_provider) }
    let(:root_group) { saml_provider.group }
    let(:project) { create(:project, group: root_group) }
    let(:sso_user) { identity.user }

    before do
      stub_licensed_features(group_saml: true)
      root_group.add_developer(sso_user)
      sign_in(sso_user)
    end

    it 'redirects to group SSO page' do
      route = "/-/ide/project/#{project.full_path}"
      redirect_route = CGI.escape(route)
      get route

      expect(response).to have_gitlab_http_status(:found)
      expect(response.location).to match(%r{groups/.*/-/saml/sso\?redirect=#{redirect_route}&token=})
    end
  end
end
