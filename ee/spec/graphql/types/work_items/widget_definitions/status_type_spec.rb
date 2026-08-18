# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::WidgetDefinitions::StatusType, feature_category: :team_planning do
  it 'exposes the expected fields' do
    expected_fields = %i[type allowed_statuses default_open_status default_closed_status]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  specify { expect(described_class.graphql_name).to eq('WorkItemWidgetDefinitionStatus') }
end
