# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::Ascp::ComponentType, feature_category: :static_application_security_testing do
  fields = %w[
    id title description sub_directory expected_user_behavior
    scan security_context dependencies created_at updated_at
  ].freeze

  specify { expect(described_class.graphql_name).to eq('AscpComponent') }

  it 'has the expected fields' do
    expect(described_class).to have_graphql_fields(*fields)
  end

  it_behaves_like 'an ASCP type with field scopes', fields: fields
end
