# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ComplianceFrameworkSort'], feature_category: :compliance_management do
  specify { expect(described_class.graphql_name).to eq('ComplianceFrameworkSort') }

  it 'exposes all the existing sort values' do
    expect(described_class.values.keys).to include(
      *%w[
        NAME_ASC
        NAME_DESC
        UPDATED_AT_ASC
        UPDATED_AT_DESC
      ]
    )
  end
end
