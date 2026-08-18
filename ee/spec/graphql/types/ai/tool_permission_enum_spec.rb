# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::ToolPermissionEnum, feature_category: :ai_agents do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiToolPermission')
  end

  it 'exposes the correct values' do
    expect(described_class.values.keys).to contain_exactly('ALLOW', 'ASK', 'DENY')
  end

  it 'maps ALLOW to allow' do
    expect(described_class.values['ALLOW'].value).to eq('allow')
  end

  it 'maps ASK to ask' do
    expect(described_class.values['ASK'].value).to eq('ask')
  end

  it 'maps DENY to deny' do
    expect(described_class.values['DENY'].value).to eq('deny')
  end
end
