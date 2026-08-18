# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::ComplianceManagement::ProjectInputType, feature_category: :compliance_management do
  it 'has correct graphql name' do
    expect(described_class.graphql_name).to eq('ComplianceFrameworkProjectInput')
  end

  it 'has correct argument keys' do
    expect(described_class.arguments.keys).to match_array(%w[addProjects removeProjects])
  end
end
