# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::ComplianceManagement::ComplianceRequirementInputType, feature_category: :compliance_management do
  it { expect(described_class.graphql_name).to eq('ComplianceRequirementInput') }

  it { expect(described_class.arguments.keys).to match_array(%w[name description complianceRequirementsControls]) }
end
