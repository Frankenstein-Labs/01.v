# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceRequirements::ExpressionEvaluator,
  feature_category: :compliance_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:control) { create(:compliance_requirements_control) }
  let(:approval_settings) { [] }

  subject(:evaluator) { described_class.new(control, project, approval_settings) }

  describe '#evaluate' do
    let(:expression) { { operator: '=', field: 'project_visibility_not_internal', value: true } }

    before do
      allow(control).to receive(:expression_as_hash)
                          .with(symbolize_names: true)
                          .and_return(expression)
    end

    context 'when expression parsing fails' do
      before do
        allow(control).to receive(:expression_as_hash)
                            .with(symbolize_names: true)
                            .and_return(nil)
      end

      it 'returns nil' do
        expect(evaluator.evaluate).to be_nil
      end
    end

    context 'when expression is valid' do
      it 'calls comparison operator with correct field value' do
        allow(ComplianceManagement::ComplianceRequirements::ProjectFields)
          .to receive(:map_field)
                .with(project, 'project_visibility_not_internal', { approval_settings: approval_settings })
                .and_return(true)

        expect(ComplianceManagement::ComplianceRequirements::ComparisonOperator)
          .to receive(:compare)
                .with(true, true, '=')

        evaluator.evaluate
      end

      it 'passes approval settings to ProjectFields.map_field' do
        expect(ComplianceManagement::ComplianceRequirements::ProjectFields)
          .to receive(:map_field)
                .with(project, 'project_visibility_not_internal', { approval_settings: approval_settings })

        evaluator.evaluate
      end
    end
  end
end
