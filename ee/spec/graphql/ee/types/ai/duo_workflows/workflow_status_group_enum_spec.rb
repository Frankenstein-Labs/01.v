# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['DuoWorkflowStatusGroup'], feature_category: :duo_agent_platform do
  it 'has specific fields' do
    expect(described_class.values.keys).to match_array(%w[
      ACTIVE PAUSED AWAITING_INPUT COMPLETED FAILED CANCELED
    ])
  end
end
