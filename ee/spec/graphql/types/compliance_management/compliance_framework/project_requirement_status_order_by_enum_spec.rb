# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ProjectComplianceRequirementStatusOrderBy'],
  feature_category: :compliance_management do
  let(:fields) do
    %w[PROJECT REQUIREMENT FRAMEWORK]
  end

  specify { expect(described_class.graphql_name).to eq('ProjectComplianceRequirementStatusOrderBy') }
  specify { expect(described_class.values.keys).to match_array(fields) }
end
