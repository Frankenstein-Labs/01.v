# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GoogleCloudNodePoolLabel'], feature_category: :runner_core do
  it 'has the correct arguments' do
    expect(described_class.arguments.keys).to match_array(%w[key value])
  end

  specify { expect(described_class.graphql_name).to eq('GoogleCloudNodePoolLabel') }
end
