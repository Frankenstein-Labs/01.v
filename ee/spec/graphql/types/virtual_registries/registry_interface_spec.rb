# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::VirtualRegistries::RegistryInterface, feature_category: :virtual_registry do
  it 'exposes the expected fields' do
    expected_field_types = {
      id: 'ID!',
      name: 'String!',
      description: 'String',
      updatedAt: 'Time!'
    }

    expect(described_class).to have_graphql_fields(*expected_field_types.keys)
    expected_field_types.each do |field_name, type_signature|
      expect(described_class.fields[field_name.to_s].type.to_type_signature).to eq(type_signature)
    end
  end
end
