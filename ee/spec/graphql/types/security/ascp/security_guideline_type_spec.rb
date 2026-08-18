# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::Ascp::SecurityGuidelineType, feature_category: :static_application_security_testing do
  fields = %w[
    id name operation legitimate_use security_boundary business_context severity_if_violated
  ].freeze

  specify { expect(described_class.graphql_name).to eq('AscpSecurityGuideline') }

  it 'has the expected fields' do
    expect(described_class).to have_graphql_fields(*fields)
  end

  it_behaves_like 'an ASCP type with field scopes', fields: fields
end
