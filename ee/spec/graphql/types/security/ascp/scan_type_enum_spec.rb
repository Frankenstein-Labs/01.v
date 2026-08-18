# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::Ascp::ScanTypeEnum, feature_category: :static_application_security_testing do
  specify { expect(described_class.graphql_name).to eq('AscpScanType') }

  it 'exposes all the existing scan type values' do
    expect(described_class.values.keys).to contain_exactly('FULL', 'INCREMENTAL')
  end
end
