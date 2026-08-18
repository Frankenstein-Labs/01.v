# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::ComplianceManagement::ComplianceRequirementsControlInputType, feature_category: :compliance_management do
  it { expect(described_class.graphql_name).to eq('ComplianceRequirementsControlInput') }

  it 'defines the expected input arguments' do
    expect(described_class.arguments.keys).to match_array(
      %w[name expression externalControlName externalUrl controlType secretToken pingEnabled]
    )
  end

  describe 'ping_enabled argument' do
    let(:ping_enabled_argument) { described_class.arguments['pingEnabled'] }

    it 'has the correct type' do
      expect(ping_enabled_argument.type).to eq(GraphQL::Types::Boolean)
    end

    it 'is not required' do
      expect(ping_enabled_argument.type.non_null?).to be(false)
    end

    it 'has the correct description' do
      expect(ping_enabled_argument.description).to eq('Whether ping is enabled for external controls.')
    end
  end
end
