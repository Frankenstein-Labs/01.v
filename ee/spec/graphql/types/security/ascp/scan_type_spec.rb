# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::Ascp::ScanType, feature_category: :static_application_security_testing do
  fields = %w[
    id scan_sequence commit_sha scan_type base_commit_sha base_scan created_at updated_at
  ].freeze

  specify { expect(described_class.graphql_name).to eq('AscpScan') }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields(*fields)
  end

  it_behaves_like 'an ASCP type with field scopes', fields: fields
end
