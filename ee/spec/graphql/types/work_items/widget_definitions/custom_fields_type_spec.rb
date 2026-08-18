# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::WidgetDefinitions::CustomFieldsType, feature_category: :team_planning do
  it 'exposes the expected fields' do
    expected_fields = %i[type custom_field_values]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  specify { expect(described_class.graphql_name).to eq('WorkItemWidgetDefinitionCustomFields') }
end
