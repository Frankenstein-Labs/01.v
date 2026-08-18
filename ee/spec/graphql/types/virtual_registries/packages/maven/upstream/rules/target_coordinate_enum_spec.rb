# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::VirtualRegistries::Packages::Maven::Upstream::Rules::TargetCoordinateEnum, feature_category: :virtual_registry do
  specify { expect(described_class.graphql_name).to eq('MavenUpstreamTargetCoordinate') }

  it { expect(described_class.values.keys).to match_array(%w[GROUP_ID ARTIFACT_ID VERSION]) }
end
