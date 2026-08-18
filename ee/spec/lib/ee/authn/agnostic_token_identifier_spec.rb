# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::AgnosticTokenIdentifier, feature_category: :system_access do
  describe '.token_type' do
    context 'when Gitlab.ee? is true' do
      let_it_be(:organization) { create(:organization) }
      let_it_be(:group) { create(:group) }
      let_it_be(:scim_oauth_token) { create(:scim_oauth_access_token, organization: organization) }
      let_it_be(:group_scim_token) { create(:group_scim_auth_access_token, group: group) }

      it 'identifies ScimOauthAccessToken' do
        expect(described_class.token_type(scim_oauth_token.token)).to eq(::Authn::Tokens::ScimAccessToken)
      end

      it 'identifies GroupScimAuthAccessToken' do
        expect(described_class.token_type(group_scim_token.token)).to eq(::Authn::Tokens::ScimAccessToken)
      end
    end
  end
end
