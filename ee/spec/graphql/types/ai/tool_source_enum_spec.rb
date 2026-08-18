# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::ToolSourceEnum, feature_category: :ai_agents do
  it 'exposes the correct values' do
    expect(described_class.values.keys).to contain_exactly('GITLAB', 'MCP')
  end

  it 'maps GITLAB to gitlab' do
    expect(described_class.values['GITLAB'].value).to eq('gitlab')
  end

  it 'maps MCP to mcp' do
    expect(described_class.values['MCP'].value).to eq('mcp')
  end
end
