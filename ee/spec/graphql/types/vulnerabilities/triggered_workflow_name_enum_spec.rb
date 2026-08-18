# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::Vulnerabilities::TriggeredWorkflowNameEnum, feature_category: :vulnerability_management do
  it 'exposes all the vulnerability workflow names' do
    expect(described_class.values.keys).to match_array(%w[SAST_FP_DETECTION RESOLVE_SAST_VULNERABILITY
      SECRETS_FP_DETECTION])
  end

  it 'has the correct descriptions' do
    expect(described_class.values['SAST_FP_DETECTION'].description).to eq('Workflow name is sast fp detection')
    expect(described_class.values['RESOLVE_SAST_VULNERABILITY'].description)
      .to eq('Workflow name is resolve sast vulnerability')
  end
end
