# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Members::RoleInterface, feature_category: :system_access do
  it 'exposes the expected fields' do
    expected_fields = %i[id name description detailsPath]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end
end
