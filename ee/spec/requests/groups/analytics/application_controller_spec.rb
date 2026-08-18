# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups::Analytics::ApplicationController', feature_category: :value_stream_management do
  let_it_be(:group) { create(:group, :private) }

  # This is an abstract class so we'll test it using an inheritor
  let(:analytics_path) { group_analytics_cycle_analytics_path(group) }

  context 'when SSO is enabled' do
    let_it_be(:saml_provider) { create(:saml_provider, group: group, enforced_sso: true) }
    let_it_be(:identity) { create(:group_saml_identity, saml_provider: saml_provider) }
    let_it_be(:user) { identity.user }

    before_all do
      group.add_reporter(user)
    end

    before do
      stub_licensed_features(group_saml: true, cycle_analytics_for_groups: true)
      sign_in(user)
    end

    context 'without SAML session' do
      it 'redirects to group\'s SSO' do
        get analytics_path

        expect(response).to have_gitlab_http_status(:found)
        expect(response.location).to match(%r{groups/#{Regexp.escape(group.to_param)}/-/saml/sso\?redirect=.+&token=})
      end
    end

    context 'with active SAML session' do
      before do
        allow_next_instance_of(Gitlab::Auth::GroupSaml::SsoEnforcer) do |enforcer|
          allow(enforcer).to receive(:active_session?).and_return(true)
        end
      end

      it 'can access group analytics' do
        get analytics_path

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end
end
