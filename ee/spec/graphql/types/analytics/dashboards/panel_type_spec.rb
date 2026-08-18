# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CustomizableDashboardPanel'], feature_category: :product_analytics do
  let(:expected_fields) do
    %i[title title_icon tooltip grid_attributes query_overrides visualization views]
  end

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }
  it { is_expected.to require_graphql_authorizations(:read_customizable_dashboards) }
end
