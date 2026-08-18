# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GroupingEnum'], feature_category: :continuous_integration do
  specify { expect(described_class.graphql_name).to eq('GroupingEnum') }

  it 'exposes all the grouping strategy values' do
    expect(described_class.values.keys).to include(
      *%w[INSTANCE_AGGREGATE PER_ROOT_NAMESPACE]
    )
  end
end
