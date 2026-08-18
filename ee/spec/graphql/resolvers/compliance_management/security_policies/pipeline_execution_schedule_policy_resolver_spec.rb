# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ComplianceManagement::SecurityPolicies::PipelineExecutionSchedulePolicyResolver, feature_category: :security_policy_management do
  include GraphqlHelpers
  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:framework) { create(:compliance_framework) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
  let_it_be(:compliance_framework_security_policy) do
    create(:compliance_framework_security_policy, policy_configuration: policy_configuration, framework: framework)
  end

  let_it_be(:policy_scope) { { compliance_frameworks: [{ id: framework.id }] } }
  let_it_be(:ref_project) { create(:project, :repository) }
  let_it_be(:content) { { project: ref_project.full_path, file: 'pipeline_execution_schedule_policy.yml' } }
  let_it_be(:policy) do
    build(:pipeline_execution_schedule_policy,
      name: 'Run my scheduled pipeline',
      policy_scope: policy_scope
    )
  end

  describe '#resolve' do
    subject(:resolve_policies) do
      sync(resolve(described_class, obj: framework, args: {}, ctx: { current_user: current_user }))
    end

    context 'when user is unauthorized' do
      it 'returns an empty array' do
        expect(resolve_policies).to be_empty
      end
    end

    context 'when user is authorized' do
      before_all do
        project.add_owner(current_user)
      end

      before do
        stub_licensed_features(security_orchestration_policies: true)

        allow_next_instance_of(Repository) do |repository|
          allow(repository).to receive(:blob_data_at).and_return(
            { pipeline_execution_schedule_policy: [policy] }.to_yaml
          )
        end
      end

      it 'returns the policy' do
        expect(resolve_policies.map { |p| p[:name] }).to match_array([policy[:name]])
      end
    end
  end
end
