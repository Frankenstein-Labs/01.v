# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::Vulnerabilities::FlagType, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:fields) { %i[confidence_score created_at description id origin status updated_at] }

  it { expect(described_class).to have_graphql_fields(*fields) }

  it { expect(described_class).to require_graphql_authorizations(:read_vulnerability) }

  describe '.authorization_scopes' do
    it 'includes :ai_workflows' do
      expect(described_class.authorization_scopes).to include(:ai_workflows)
    end
  end

  describe 'field types' do
    specify { expect(described_class.fields['confidenceScore']).to have_graphql_type(GraphQL::Types::Float) }
    specify { expect(described_class.fields['createdAt']).to have_graphql_type(Types::TimeType, null: false) }
    specify { expect(described_class.fields['description']).to have_graphql_type(GraphQL::Types::String) }
    specify { expect(described_class.fields['id']).to have_graphql_type(GraphQL::Types::ID, null: false) }
    specify { expect(described_class.fields['origin']).to have_graphql_type(GraphQL::Types::String) }

    specify do
      expect(described_class.fields['status'])
        .to have_graphql_type(Types::Vulnerabilities::Flags::FalsePositiveDetectionStatusEnum)
    end

    specify { expect(described_class.fields['updatedAt']).to have_graphql_type(Types::TimeType, null: false) }
  end
end
