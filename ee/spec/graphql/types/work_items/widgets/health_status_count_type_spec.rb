# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::Widgets::HealthStatusCountType, feature_category: :team_planning do
  let(:fields) do
    %i[health_status count]
  end

  specify { expect(described_class).to have_graphql_fields(fields) }

  specify { expect(described_class.graphql_name).to eq('WorkItemWidgetHealthStatusCount') }
end
