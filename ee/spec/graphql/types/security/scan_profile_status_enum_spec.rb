# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::ScanProfileStatusEnum, feature_category: :security_testing_configuration do
  specify { expect(described_class.graphql_name).to eq('ScanProfileStatus') }

  it 'has the expected values' do
    expect(described_class.values.keys).to contain_exactly(
      'NOT_CONFIGURED',
      'PENDING',
      'ACTIVE',
      'WARNING',
      'FAILED',
      'STALE'
    )
  end
end
