# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::ItemReportReasonEnum, feature_category: :workflow_catalog do
  specify { expect(described_class.graphql_name).to eq('AiCatalogItemReportReason') }

  it 'exposes all report reason values' do
    expect(described_class.values.keys).to match_array(
      %w[IMMEDIATE_SECURITY_THREAT POTENTIAL_SECURITY_THREAT EXCESSIVE_RESOURCE_USAGE SPAM_OR_LOW_QUALITY OTHER]
    )
  end

  describe 'values' do
    it 'has correct descriptions' do
      expect(described_class.values['IMMEDIATE_SECURITY_THREAT'].description)
        .to eq('Contains dangerous code, exploits, or harmful actions.')
      expect(described_class.values['POTENTIAL_SECURITY_THREAT'].description)
        .to eq('Hypothetical or low risk security flaws that could be exploited.')
      expect(described_class.values['EXCESSIVE_RESOURCE_USAGE'].description)
        .to eq('Wasting compute or causing performance issues.')
      expect(described_class.values['SPAM_OR_LOW_QUALITY'].description)
        .to eq('Frequently failing or nuisance activity.')
      expect(described_class.values['OTHER'].description)
        .to eq('Please describe below.')
    end

    it 'has correct values' do
      expect(described_class.values['IMMEDIATE_SECURITY_THREAT'].value).to eq('immediate_security_threat')
      expect(described_class.values['POTENTIAL_SECURITY_THREAT'].value).to eq('potential_security_threat')
      expect(described_class.values['EXCESSIVE_RESOURCE_USAGE'].value).to eq('excessive_resource_usage')
      expect(described_class.values['SPAM_OR_LOW_QUALITY'].value).to eq('spam_or_low_quality')
      expect(described_class.values['OTHER'].value).to eq('other')
    end
  end
end
