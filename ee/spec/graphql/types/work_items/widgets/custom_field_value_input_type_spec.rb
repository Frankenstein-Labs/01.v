# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::WorkItems::Widgets::CustomFieldValueInputType, feature_category: :team_planning do
  it { expect(described_class.graphql_name).to eq('WorkItemWidgetCustomFieldValueInputType') }

  it 'has correct arguments' do
    expect(described_class.arguments.keys).to contain_exactly(
      'customFieldId', 'selectedOptionIds', 'numberValue', 'textValue', 'dateValue'
    )
  end
end
