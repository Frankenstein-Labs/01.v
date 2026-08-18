# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::DuoWorkflows::DuoMessageType, feature_category: :duo_agent_platform do
  subject(:fields) { described_class.fields }

  it 'includes the expected fields' do
    expect(described_class).to have_graphql_fields(
      :content,
      :message_type,
      :message_sub_type,
      :status,
      :tool_info,
      :timestamp,
      :correlation_id,
      :message_id,
      :additional_context,
      :role,
      :component_name,
      :subsession_id,
      :thread_ts,
      :parent_ts,
      :alternative_count
    )
  end

  describe 'additionalContext field' do
    subject(:field) { fields['additionalContext'] }

    it 'is a list of AiAdditionalContext' do
      expect(field.type.of_type.of_type).to eq(Types::Ai::AdditionalContextType)
    end
  end

  describe 'experimental message metadata fields' do
    it 'are nullable strings' do
      expect(fields['messageSubType']).to have_nullable_graphql_type(GraphQL::Types::String)
      expect(fields['componentName']).to have_nullable_graphql_type(GraphQL::Types::String)
      expect(fields['subsessionId']).to have_nullable_graphql_type(GraphQL::Types::String)
      expect(fields['threadTs']).to have_nullable_graphql_type(GraphQL::Types::String)
      expect(fields['parentTs']).to have_nullable_graphql_type(GraphQL::Types::String)
    end

    it 'expose the alternative count as a nullable integer' do
      expect(fields['alternativeCount']).to have_nullable_graphql_type(GraphQL::Types::Int)
    end

    it 'include expected scopes' do
      %w[messageSubType componentName subsessionId threadTs parentTs alternativeCount].each do |field_name|
        expect(fields[field_name].instance_variable_get(:@scopes))
          .to include(:api, :read_api, :ai_features, :ai_workflows)
      end
    end
  end
end
