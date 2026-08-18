# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ComplianceRequirement'], feature_category: :compliance_management do
  subject { described_class }

  fields = %w[
    id
    name
    description
    complianceRequirementsControls
    framework
  ]

  it 'has the correct fields' do
    is_expected.to have_graphql_fields(fields)
  end
end
