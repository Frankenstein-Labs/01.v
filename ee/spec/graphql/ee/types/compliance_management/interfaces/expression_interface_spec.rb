# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::ComplianceManagement::Interfaces::ExpressionInterface, feature_category: :compliance_management do
  let(:interface) { described_class }

  it 'has the correct name' do
    expect(interface.graphql_name).to eq('ExpressionInterface')
  end

  it 'has the correct description' do
    expect(interface.description).to eq('Defines the common fields for all expressions.')
  end

  describe 'fields' do
    let(:fields) { interface.fields }

    it 'has a field field' do
      expect(fields['field']).to be_present
      expect(fields['field'].type.to_type_signature).to eq('String!')
      expect(fields['field'].description).to eq('Field the expression applies to.')
    end

    it 'has an operator field' do
      expect(fields['operator']).to be_present
      expect(fields['operator'].type.to_type_signature).to eq('String!')
      expect(fields['operator'].description).to eq('Operator of the expression.')
    end
  end
end
