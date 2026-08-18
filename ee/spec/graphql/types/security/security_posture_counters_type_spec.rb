# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::SecurityPostureCountersType, feature_category: :security_asset_inventories do
  let(:expected_fields) { %i[with_scanners with_failures with_stale] }

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }
end
