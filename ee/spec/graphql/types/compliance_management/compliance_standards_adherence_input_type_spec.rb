# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ComplianceStandardsAdherenceInput'], feature_category: :compliance_management do
  subject { described_class }

  arguments = %w[
    projectIds
    checkName
    standard
  ]

  it { expect(described_class.graphql_name).to eq('ComplianceStandardsAdherenceInput') }

  it { expect(described_class.arguments.keys).to match_array(arguments) }
end
