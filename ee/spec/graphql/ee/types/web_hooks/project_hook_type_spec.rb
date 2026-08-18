# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ProjectHook'], feature_category: :webhooks do
  it 'has specific fields' do
    expected_fields = %i[
      vulnerability_events
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
