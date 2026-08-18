# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::McpServerAuthTypeEnum, feature_category: :workflow_catalog do
  it 'exposes all auth type options' do
    expect(described_class.values.keys).to match_array(%w[OAUTH NO_AUTH])
  end

  it 'has correct values' do
    expect(described_class.values['OAUTH'].value).to eq('oauth')
    expect(described_class.values['NO_AUTH'].value).to eq('no_auth')
  end
end
