# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ProjectComplianceViolationFilterInput'], feature_category: :compliance_management do
  let(:arguments) do
    %w[projectId controlId status createdBefore createdAfter]
  end

  specify { expect(described_class.graphql_name).to eq('ProjectComplianceViolationFilterInput') }
  specify { expect(described_class.arguments.keys).to match_array(arguments) }
end
