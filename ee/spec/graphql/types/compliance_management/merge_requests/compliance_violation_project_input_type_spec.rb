# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ComplianceViolationProjectInput'], feature_category: :compliance_management do
  let(:arguments) do
    %w[mergedBefore mergedAfter targetBranch]
  end

  specify { expect(described_class.graphql_name).to eq('ComplianceViolationProjectInput') }
  specify { expect(described_class.arguments.keys).to match_array(arguments) }
end
