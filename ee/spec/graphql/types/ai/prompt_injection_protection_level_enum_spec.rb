# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PromptInjectionProtectionLevel'], feature_category: :duo_chat do
  let(:expected_values) { %w[NO_CHECKS LOG_ONLY INTERRUPT] }

  subject { described_class.values.keys }

  it { is_expected.to match_array(expected_values) }

  describe 'enum values' do
    it 'has correct value for NO_CHECKS' do
      expect(described_class.values['NO_CHECKS'].value).to eq('no_checks')
    end

    it 'has correct value for LOG_ONLY' do
      expect(described_class.values['LOG_ONLY'].value).to eq('log_only')
    end

    it 'has correct value for INTERRUPT' do
      expect(described_class.values['INTERRUPT'].value).to eq('interrupt')
    end
  end

  describe 'descriptions' do
    it 'has description for NO_CHECKS' do
      expect(described_class.values['NO_CHECKS'].description).to include('Turn off scanning entirely')
    end

    it 'has description for LOG_ONLY' do
      expect(described_class.values['LOG_ONLY'].description).to include('Scan and log results')
    end

    it 'has description for INTERRUPT' do
      expect(described_class.values['INTERRUPT'].description).to include('Scan and block detected')
    end
  end
end
