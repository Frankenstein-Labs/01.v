# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ProjectRequirementComplianceStatusInput'], feature_category: :compliance_management do
  let(:arguments) do
    %w[requirementId frameworkId]
  end

  specify { expect(described_class.graphql_name).to eq('ProjectRequirementComplianceStatusInput') }
  specify { expect(described_class.arguments.keys).to match_array(arguments) }
end
