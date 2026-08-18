# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::Dora::PerformanceScoreConnectionType, feature_category: :dora_metrics do
  include GraphqlHelpers

  let(:fields) { %i[total_projects_count no_dora_data_projects_count] }

  specify { expect(described_class.graphql_name).to eq('DoraPerformanceScoreConnectionType') }

  specify do
    expect(described_class.description)
      .to eq('Connection details for aggregated DORA metrics for a collection of projects')
  end

  specify { expect(described_class).to have_graphql_fields(fields).at_least }
end
