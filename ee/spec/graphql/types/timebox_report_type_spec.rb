# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['TimeboxReport'], feature_category: :portfolio_management do
  it { expect(described_class.graphql_name).to eq('TimeboxReport') }

  it { expect(described_class).to have_graphql_field(:burnup_time_series) }
end
