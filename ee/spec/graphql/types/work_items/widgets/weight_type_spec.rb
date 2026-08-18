# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::Widgets::WeightType, feature_category: :team_planning do
  let(:fields) do
    %i[type widget_definition weight rolled_up_weight rolled_up_completed_weight]
  end

  specify { expect(described_class).to have_graphql_fields(fields) }

  specify { expect(described_class.graphql_name).to eq('WorkItemWidgetWeight') }
end
