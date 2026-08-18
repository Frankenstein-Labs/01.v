# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::BackgroundToolPermissionEnum, feature_category: :ai_agents do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiBackgroundToolPermission')
  end

  it 'exposes only allow and deny (ask has no meaning on a background flow)' do
    expect(described_class.values.keys).to contain_exactly('ALLOW', 'DENY')
  end

  it 'maps ALLOW to allow' do
    expect(described_class.values['ALLOW'].value).to eq('allow')
  end

  it 'maps DENY to deny' do
    expect(described_class.values['DENY'].value).to eq('deny')
  end
end
