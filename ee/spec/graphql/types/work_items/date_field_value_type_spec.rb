# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::DateFieldValueType, feature_category: :team_planning do
  let(:fields) do
    %i[customField value]
  end

  specify { expect(described_class).to have_graphql_fields(fields) }

  specify { expect(described_class.graphql_name).to eq('WorkItemDateFieldValue') }

  describe '.authorization_scopes' do
    it 'allows ai_workflows scope token' do
      expect(described_class.authorization_scopes).to include(:ai_workflows)
    end
  end

  describe 'fields with :ai_workflows scope' do
    it 'includes :ai_workflows scope for the value field' do
      expect(described_class.fields['value']).to include_graphql_scopes(:ai_workflows)
    end
  end
end
