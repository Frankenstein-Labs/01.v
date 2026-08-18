# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::ComplianceManagement::ComplianceRequirementControlType, feature_category: :compliance_management do
  let(:type) { described_class }

  it 'has the correct name' do
    expect(type.graphql_name).to eq('ComplianceRequirementControl')
  end

  it 'has the correct description' do
    expect(type.description).to eq('Lists down all the possible types of requirement controls.')
  end

  describe 'fields' do
    let(:fields) { type.fields }

    it 'has a control_expressions field' do
      expect(fields['controlExpressions']).to be_present
      expect(fields['controlExpressions'].type.to_type_signature).to eq('[ControlExpression!]!')
      expect(fields['controlExpressions'].description).to eq('List of requirement controls.')
    end
  end
end
