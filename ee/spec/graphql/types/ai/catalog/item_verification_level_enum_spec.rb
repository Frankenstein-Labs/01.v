# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiCatalogItemVerificationLevel'], feature_category: :workflow_catalog do
  it 'exposes all item types' do
    expect(described_class.values.keys).to match_array(%w[
      UNVERIFIED
      GITLAB_MAINTAINED
      GITLAB_PARTNER_MAINTAINED
      VERIFIED_CREATOR_MAINTAINED
      VERIFIED_CREATOR_SELF_MANAGED
    ])
  end
end
