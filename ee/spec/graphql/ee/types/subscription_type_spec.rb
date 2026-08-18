# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Subscription'], feature_category: :api do
  it 'has the expected fields' do
    expected_fields = %i[
      issuable_weight_updated
      issuable_iteration_updated
      issuable_health_status_updated
      issuable_epic_updated
      workflow_events_updated
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe '.authorization' do
    it 'allows ai_features scope token' do
      expect(described_class.authorization.permitted_scopes).to include(:ai_features)
    end
  end
end
