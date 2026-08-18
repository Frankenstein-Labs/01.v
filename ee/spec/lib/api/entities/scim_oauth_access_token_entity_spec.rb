# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::ScimOauthAccessToken, feature_category: :system_access do
  let_it_be(:scim_token) { build_stubbed(:scim_oauth_access_token, organization_id: 1, group_id: 2) }
  let(:hash) { described_class.new(scim_token).as_json }

  it 'exposes attributes' do
    expect(hash.keys).to match_array(%i[
      id
      created_at
      group_id
      organization_id
    ])
  end
end
