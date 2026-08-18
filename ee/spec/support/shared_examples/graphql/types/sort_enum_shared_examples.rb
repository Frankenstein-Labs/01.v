# frozen_string_literal: true

RSpec.shared_examples 'sort enum type with additional fields' do
  let(:sort_enum_values) do
    %w[
      CREATED_ASC CREATED_DESC
      UPDATED_ASC UPDATED_DESC
      created_asc created_desc
      updated_asc updated_desc
    ]
  end

  let(:additional_values) { [] }

  it 'has specific fields' do
    expect(described_class.values.keys).to match_array(sort_enum_values + additional_values)
  end
end
