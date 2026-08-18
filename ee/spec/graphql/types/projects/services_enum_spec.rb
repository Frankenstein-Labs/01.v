# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ServiceType'], feature_category: :team_planning do
  it 'exposes all the EE project services' do
    expect(described_class.values.keys).to include(*ee_service_enums)
  end

  def ee_service_enums
    %w[
      GITHUB_SERVICE
    ]
  end

  it 'coerces values correctly' do
    integration = build(:github_integration)

    expect(described_class.coerce_isolated_result(integration.type)).to eq 'GITHUB_SERVICE'
  end
end
