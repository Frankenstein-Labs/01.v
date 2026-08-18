# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountComplianceRequirementsMetric, feature_category: :compliance_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: namespace) }
  let_it_be(:requirement) { create(:compliance_requirement, framework: framework, name: 'Base Requirement') }

  let_it_be(:requirement_with_control1) do
    create(:compliance_requirement, framework: framework, name: 'Control Requirement 1')
  end

  let_it_be(:requirement_with_control2) do
    create(:compliance_requirement, framework: framework, name: 'Control Requirement 2')
  end

  let_it_be(:requirement_with_policy1) do
    create(:compliance_requirement, framework: framework, name: 'Policy Requirement 1')
  end

  let_it_be(:requirement_with_policy2) do
    create(:compliance_requirement, framework: framework, name: 'Policy Requirement 2')
  end

  let_it_be(:requirement_with_policy3) do
    create(:compliance_requirement, framework: framework, name: 'Policy Requirement 3')
  end

  before_all do
    create(:compliance_requirements_control, compliance_requirement: requirement_with_control1)
    create(:compliance_requirements_control, compliance_requirement: requirement_with_control2)

    policy1 = create(:compliance_framework_security_policy, framework: framework)
    policy2 = create(:compliance_framework_security_policy, framework: framework)
    policy3 = create(:compliance_framework_security_policy, framework: framework)

    create(:security_policy_requirement,
      compliance_requirement: requirement_with_policy1,
      compliance_framework_security_policy: policy1
    )

    create(:security_policy_requirement,
      compliance_requirement: requirement_with_policy2,
      compliance_framework_security_policy: policy2
    )

    create(:security_policy_requirement,
      compliance_requirement: requirement_with_policy3,
      compliance_framework_security_policy: policy3
    )
  end

  context 'with controls metric type' do
    it_behaves_like 'a correct instrumented metric value and query',
      { time_frame: 'all', options: { metric_type: 'with_controls' } } do
      let(:expected_value) { 2 }
      let(:expected_query) do
        <<~SQL.squish
          SELECT COUNT(DISTINCT "compliance_requirements"."id")#{' '}
          FROM "compliance_requirements"
          INNER JOIN "compliance_requirements_controls"#{' '}
            ON "compliance_requirements_controls"."compliance_requirement_id" = "compliance_requirements"."id"
        SQL
      end
    end
  end

  context 'with policies metric type' do
    it_behaves_like 'a correct instrumented metric value and query',
      { time_frame: 'all', options: { metric_type: 'with_policies' } } do
      let(:expected_value) { 3 }
      let(:expected_query) do
        <<~SQL.squish
          SELECT COUNT(DISTINCT "compliance_requirements"."id")#{' '}
          FROM "compliance_requirements"
          INNER JOIN "security_policy_requirements"#{' '}
            ON "security_policy_requirements"."compliance_requirement_id" = "compliance_requirements"."id"
          INNER JOIN "compliance_framework_security_policies"#{' '}
            ON "compliance_framework_security_policies"."id" = "security_policy_requirements"."compliance_framework_security_policy_id"
        SQL
      end
    end
  end

  describe 'invalid metric type' do
    it 'raises an error' do
      expect do
        described_class.new(time_frame: 'all', options: { metric_type: 'invalid' })
      end.to raise_error(ArgumentError, /Unknown metric type: invalid/)
    end
  end
end
