# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['RiskRating'], feature_category: :vulnerability_management do
  it { expect(described_class.graphql_name).to eq('RiskRating') }
  it { expect(described_class.description).to eq('Risk rating levels based on score ranges') }

  describe 'enum values' do
    let(:expected_values) { %w[LOW MEDIUM HIGH CRITICAL UNKNOWN] }

    it 'has the correct enum values' do
      expect(described_class.values.keys).to match_array(expected_values)
    end

    it 'has correct value mappings' do
      expect(described_class.values['LOW'].value).to eq('low')
      expect(described_class.values['MEDIUM'].value).to eq('medium')
      expect(described_class.values['HIGH'].value).to eq('high')
      expect(described_class.values['CRITICAL'].value).to eq('critical')
      expect(described_class.values['UNKNOWN'].value).to eq('unknown')
    end

    it 'has correct descriptions' do
      expect(described_class.values['LOW'].description).to eq('Low risk (0-25).')
      expect(described_class.values['MEDIUM'].description).to eq('Medium risk (26-50).')
      expect(described_class.values['HIGH'].description).to eq('High risk (51-75).')
      expect(described_class.values['CRITICAL'].description).to eq('Critical risk (76-100).')
      expect(described_class.values['UNKNOWN'].description).to eq('Unknown risk level.')
    end
  end
end
