# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CustomizableDashboardPanelTooltip'], feature_category: :product_analytics do
  let(:expected_fields) do
    %i[description description_link]
  end

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }
end
