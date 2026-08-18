# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Sbom::DependencyLocationType, feature_category: :dependency_management do
  it { expect(described_class.graphql_name).to eq('DependencyLocation') }
  it { expect(described_class).to have_graphql_fields(:occurrence_id, :location, :has_dependency_paths, :project) }
end
