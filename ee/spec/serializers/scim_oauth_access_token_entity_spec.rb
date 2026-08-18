# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScimOauthAccessTokenEntity, feature_category: :user_management do
  let(:entity) do
    described_class.new(build_stubbed(:scim_oauth_access_token))
  end

  subject { entity.as_json }

  it "exposes the URL" do
    is_expected.to include(:scim_api_url)
  end

  it "exposes the token" do
    is_expected.to include(:scim_token)
  end
end
