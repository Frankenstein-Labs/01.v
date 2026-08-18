# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['EpicList'], feature_category: :planning_views do
  specify { expect(described_class.graphql_name).to eq('EpicList') }

  it 'has specific fields' do
    expected_fields = %w[id title list_type position label epics collapsed metadata]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
