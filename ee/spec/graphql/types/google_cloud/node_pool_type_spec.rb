# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GoogleCloudNodePool'], feature_category: :runner_core do
  it 'has the correct arguments' do
    expect(described_class.arguments.keys).to match_array(%w[imageType labels machineType name nodeCount])
  end

  specify { expect(described_class.graphql_name).to eq('GoogleCloudNodePool') }
end
