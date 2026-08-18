# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CustomFieldType'], feature_category: :team_planning do
  specify { expect(described_class.graphql_name).to eq('CustomFieldType') }

  it 'exposes all custom field type values' do
    expect(described_class.values.keys).to match_array(
      Issuables::CustomField.field_types.keys.map(&:to_s).map(&:upcase)
    )
  end
end
