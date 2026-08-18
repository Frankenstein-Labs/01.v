# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::ComplianceManagement::ControlExpressionType, feature_category: :compliance_management do
  let(:type) { described_class }

  it 'has the correct name' do
    expect(type.graphql_name).to eq('ControlExpression')
  end

  it 'has the correct description' do
    expect(type.description).to eq('Represents a control expression.')
  end

  describe 'fields' do
    let(:fields) { type.fields }

    it 'has an expression field' do
      expect(fields['expression']).to be_present
      expect(fields['expression'].type.to_type_signature).to eq('ExpressionValue!')
      expect(fields['expression'].description).to eq('Expression details for the control.')
    end

    it 'has an id field' do
      expect(fields['id']).to be_present
      expect(fields['id'].type.to_type_signature).to eq('ID!')
      expect(fields['id'].description).to eq('ID for the control.')
    end

    it 'has a name field' do
      expect(fields['name']).to be_present
      expect(fields['name'].type.to_type_signature).to eq('String!')
      expect(fields['name'].description).to eq('Name of the control.')
    end
  end
end
