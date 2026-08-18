# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::LifecycleType, feature_category: :team_planning do
  specify { expect(described_class.graphql_name).to eq('WorkItemLifecycle') }

  it 'has expected fields' do
    expected_fields = %i[
      id
      name
      default_open_status
      default_closed_status
      default_duplicate_status
      work_item_types
      statuses
      status_counts
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  describe 'authorization scopes' do
    it 'includes :ai_workflows in the type-level authorization scopes' do
      expect(described_class.authorization_scopes).to include(:ai_workflows)
    end
  end

  describe 'fields with :ai_workflows scope' do
    %w[id name statuses].each do |field_name|
      it "includes :ai_workflows scope for the #{field_name} field" do
        field = described_class.fields[field_name.camelize(:lower)]
        expect(field.instance_variable_get(:@scopes)).to include(:ai_workflows)
      end
    end
  end
end
