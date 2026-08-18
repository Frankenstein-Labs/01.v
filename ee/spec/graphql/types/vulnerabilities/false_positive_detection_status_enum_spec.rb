# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['VulnerabilityFalsePositiveDetectionStatus'], feature_category: :vulnerability_management do
  it 'exposes all the existing false positive detection statuses' do
    expect(described_class.values.keys).to match_array(%w[NOT_STARTED DISMISSED DETECTED_AS_FP DETECTED_AS_NOT_FP
      FAILED])
  end

  it 'has the correct descriptions' do
    expect(described_class.values['NOT_STARTED'].description).to eq('Detection is not started')
    expect(described_class.values['DISMISSED'].description).to eq('Detection is dismissed')
    expect(described_class.values['DETECTED_AS_FP'].description).to eq('Detection is detected as fp')
    expect(described_class.values['DETECTED_AS_NOT_FP'].description).to eq('Detection is detected as not fp')
    expect(described_class.values['FAILED'].description).to eq('Detection is failed')
  end
end
