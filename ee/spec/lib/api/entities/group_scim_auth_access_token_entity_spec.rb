# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::GroupScimAuthAccessToken, feature_category: :system_access do
  let_it_be(:group_scim_token) { build_stubbed(:group_scim_auth_access_token, group_id: 1) }
  let(:hash) { described_class.new(group_scim_token).as_json }

  it 'exposes attributes' do
    expect(hash.keys).to match_array(%i[
      id
      created_at
      group_id
    ])
  end
end
