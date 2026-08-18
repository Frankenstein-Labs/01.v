# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ci::Catalog::ResourceType, feature_category: :pipeline_composition do
  it 'includes the ee specific fields' do
    expected_fields = %w[projectComponentUsages]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe 'projectComponentUsages field' do
    subject(:field) { described_class.fields['projectComponentUsages'] }

    it { is_expected.to have_graphql_type(Types::Ci::Catalog::Resources::ProjectUsageType.connection_type) }

    it 'limits field call count to 1' do
      expect(field.extensions).to include(a_kind_of(::Gitlab::Graphql::Limit::FieldCallCount))
    end
  end
end
