# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::GitlabSubscriptions::AddOnTypeEnum, feature_category: :subscription_management do
  specify { expect(described_class.graphql_name).to eq('GitlabSubscriptionsAddOnType') }

  it 'exposes all add-on types' do
    expect(described_class.values.keys)
      .to contain_exactly('DUO_CORE', 'CODE_SUGGESTIONS', 'DUO_ENTERPRISE', 'DUO_AMAZON_Q')
  end
end
