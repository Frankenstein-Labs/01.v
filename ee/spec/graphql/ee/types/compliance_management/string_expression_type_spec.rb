# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::ComplianceManagement::StringExpressionType, feature_category: :compliance_management do
  let(:type) { described_class }

  it 'has the correct name' do
    expect(type.graphql_name).to eq('StringExpression')
  end

  it 'has the correct description' do
    expect(type.description).to eq('an expression with a string value.')
  end

  it 'implements the ExpressionInterface' do
    expect(type.interfaces).to include(Types::ComplianceManagement::Interfaces::ExpressionInterface)
  end

  describe 'fields' do
    let(:fields) { type.fields }

    it 'has a value field' do
      expect(fields['value']).to be_present
      expect(fields['value'].type.to_type_signature).to eq('String!')
      expect(fields['value'].description).to eq('String value of the expression.')
    end
  end
end
