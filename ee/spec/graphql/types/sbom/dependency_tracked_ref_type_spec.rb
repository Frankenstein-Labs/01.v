# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Sbom::DependencyTrackedRefType, feature_category: :dependency_management do
  it { expect(described_class.graphql_name).to eq('DependencyTrackedRef') }
  it { expect(described_class).to have_graphql_fields(:id, :name, :ref_type, :is_default) }
end
