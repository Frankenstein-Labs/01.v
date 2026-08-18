# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::ToolActionTypeEnum, feature_category: :ai_agents do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiToolActionType')
  end

  it 'exposes the correct values' do
    expect(described_class.values.keys).to contain_exactly('READ', 'WRITE', 'DESTROY')
  end

  it 'maps READ to :read' do
    expect(described_class.values['READ'].value).to eq(:read)
  end

  it 'maps WRITE to :write' do
    expect(described_class.values['WRITE'].value).to eq(:write)
  end

  it 'maps DESTROY to :destroy' do
    expect(described_class.values['DESTROY'].value).to eq(:destroy)
  end
end
