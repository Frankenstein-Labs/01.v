# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Sbom::DependencyPathEdge, feature_category: :dependency_management do
  let_it_be(:fields) { %i[node cursor] }

  it { expect(described_class).to have_graphql_fields(fields) }
end
