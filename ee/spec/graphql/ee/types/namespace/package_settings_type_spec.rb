# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PackageSettings'], feature_category: :package_registry do
  it 'includes the expected fields' do
    expected_fields = %i[
      audit_events_enabled
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
