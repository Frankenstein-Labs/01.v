# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::ComplianceManagement::ExpressionUnion, feature_category: :compliance_management do
  let(:union) { described_class }

  describe '.resolve_type' do
    let(:context) { {} }

    it 'resolves to BooleanExpressionType for boolean values' do
      object = { value: true }
      expect(union.resolve_type(object, context)).to eq(Types::ComplianceManagement::BooleanExpressionType)
    end

    it 'resolves to IntegerExpressionType for integer values' do
      object = { value: 42 }
      expect(union.resolve_type(object, context)).to eq(Types::ComplianceManagement::IntegerExpressionType)
    end

    it 'resolves to StringExpressionType for string values' do
      object = { value: "test" }
      expect(union.resolve_type(object, context)).to eq(Types::ComplianceManagement::StringExpressionType)
    end

    it 'raises a TypeNotSupportedError for unexpected value types' do
      object = { value: [1, 2, 3] }
      expect { union.resolve_type(object, context) }.to raise_error(
        Types::ComplianceManagement::ExpressionUnion::TypeNotSupportedError,
        "Unexpected expression type: Array"
      )
    end
  end
end
