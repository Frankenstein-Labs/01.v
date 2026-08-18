# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::VirtualRegistries::Packages::Maven::Upstream::Rules::PatternTypeEnum, feature_category: :virtual_registry do
  specify { expect(described_class.graphql_name).to eq('MavenUpstreamPatternType') }

  it { expect(described_class.values.keys).to match_array(%w[WILDCARD REGEX]) }
end
