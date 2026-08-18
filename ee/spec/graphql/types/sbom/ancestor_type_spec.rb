# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Sbom::AncestorType, feature_category: :dependency_management do
  let(:fields) { %i[name version] }

  it { expect(described_class).to have_graphql_fields(fields) }
end
