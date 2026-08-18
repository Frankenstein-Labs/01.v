# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::ScanProfileProjectStatusType, feature_category: :security_testing_configuration do
  specify { expect(described_class.graphql_name).to eq('ScanProfileProjectStatus') }

  it 'has the expected fields' do
    expected_fields = %w[
      scan_profile
      status
      consecutive_failure_count
      consecutive_success_count
      last_scan_at
      build_id
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  it 'delegates authorization to the parent field' do
    expect(described_class.authorize).to be_nil
  end
end
