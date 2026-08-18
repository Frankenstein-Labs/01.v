# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceRequirements::ComparisonOperator,
  feature_category: :compliance_management do
  using RSpec::Parameterized::TableSyntax

  describe '.compare' do
    where(:operator, :actual, :expected, :result) do
      '='  | 5 | 5 | true
      '='  | 5 | 6 | false
      '!=' | 5 | 6 | true
      '!=' | 5 | 5 | false
      '>'  | 6 | 5 | true
      '>'  | 5 | 6 | false
      '<'  | 5 | 6 | true
      '<'  | 6 | 5 | false
      '>=' | 6 | 5 | true
      '>=' | 5 | 5 | true
      '<=' | 5 | 6 | true
      '<=' | 5 | 5 | true
    end

    with_them do
      it "compares correctly when operator is #{params[:operator]}" do
        expect(described_class.compare(actual, expected, operator)).to eq(result)
      end
    end

    context 'with invalid operator' do
      it 'raises error' do
        expect { described_class.compare(5, 5, 'invalid') }
          .to raise_error(ArgumentError, 'Unknown operator: invalid')
      end
    end
  end
end
