# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::ComplianceManagement::ComplianceFrameworkInputType, feature_category: :compliance_management do
  it 'has correct graphql name' do
    expect(described_class.graphql_name).to eq('ComplianceFrameworkInput')
  end

  it 'has correct argument keys' do
    expect(described_class.arguments.keys).to match_array(%w[name description color default
      pipelineConfigurationFullPath projects])
  end
end
