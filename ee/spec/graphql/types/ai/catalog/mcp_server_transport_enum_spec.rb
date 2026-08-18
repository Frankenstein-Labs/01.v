# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::McpServerTransportEnum, feature_category: :workflow_catalog do
  it 'exposes all transport options' do
    expect(described_class.values.keys).to match_array(%w[HTTP])
  end

  it 'has correct values' do
    expect(described_class.values['HTTP'].value).to eq('http')
  end
end
