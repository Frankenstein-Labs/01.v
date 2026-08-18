# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GroupProjectRequirementComplianceStatusInput'], feature_category: :compliance_management do
  let(:arguments) do
    %w[projectId requirementId frameworkId]
  end

  specify { expect(described_class.graphql_name).to eq('GroupProjectRequirementComplianceStatusInput') }
  specify { expect(described_class.arguments.keys).to match_array(arguments) }
end
