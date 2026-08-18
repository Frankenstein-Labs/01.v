# frozen_string_literal: true

RSpec.shared_examples 'projects graphql query with SAML session filtering' do
  include GraphqlHelpers

  let_it_be(:saml_provider, freeze: false) { create(:saml_provider, enabled: true, enforced_sso: true) }
  let_it_be(:saml_group, freeze: false) do
    create(:group, saml_provider: saml_provider, developers: current_user) do |group|
      create(:group_saml_identity, saml_provider: group.saml_provider, user: current_user)
    end
  end

  let_it_be(:saml_project, freeze: false) { create(:project, group: saml_group, developers: current_user) }

  before do
    stub_licensed_features(group_saml: true)
  end

  shared_examples 'includes SAML project' do
    it 'includes SAML project' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data_at(*path)).to include(a_graphql_entity_for(saml_project))
    end
  end

  context 'when current user has an active SAML session' do
    before do
      active_saml_sessions = { saml_group.saml_provider.id => Time.current }
      allow(::Gitlab::Auth::GroupSaml::SsoState).to receive(:active_saml_sessions).and_return(active_saml_sessions)
    end

    it_behaves_like 'includes SAML project'
  end

  context 'when current user has no active SAML session' do
    context 'when in the context of web activity' do
      around do |example|
        session = { 'warden.user.user.key' => [[current_user.id], current_user.authenticatable_salt] }
        Gitlab::Session.with_session(session) do
          example.run
        end
      end

      it 'excludes SAML project' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(*path)).not_to include(a_graphql_entity_for(saml_project))
      end
    end

    context 'when not in the context of web activity' do
      it_behaves_like 'includes SAML project'
    end
  end
end
