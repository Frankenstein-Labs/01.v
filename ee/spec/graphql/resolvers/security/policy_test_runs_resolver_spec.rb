# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::PolicyTestRunsResolver, feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:policy_management_project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let_it_be(:policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      security_policy_management_project: policy_management_project,
      project: project
    )
  end

  let_it_be(:security_policy) do
    create(:security_policy, :pipeline_execution_schedule_policy,
      name: 'test-policy',
      security_orchestration_policy_configuration: policy_configuration)
  end

  let(:policy_hash) do
    {
      policy_index: 0,
      type: 'pipeline_execution_schedule_policy',
      config: policy_configuration
    }
  end

  let(:ctx) { { current_user: user } }

  subject(:resolve_test_runs) { resolve(described_class, obj: policy_hash, ctx: ctx) }

  describe '#resolve' do
    context 'when policy type is not pipeline_execution_schedule_policy' do
      let(:policy_hash) do
        {
          policy_index: 0,
          type: 'scan_execution_policy',
          config: policy_configuration
        }
      end

      it 'returns empty results' do
        expect(resolve_test_runs.items).to be_empty
      end
    end

    context 'when policy_index is nil' do
      let(:policy_hash) do
        {
          policy_index: nil,
          type: 'pipeline_execution_schedule_policy',
          config: policy_configuration
        }
      end

      it 'returns empty results' do
        expect(resolve_test_runs.items).to be_empty
      end
    end

    context 'when config is nil' do
      let(:policy_hash) do
        {
          policy_index: 0,
          type: 'pipeline_execution_schedule_policy',
          config: nil
        }
      end

      it 'returns empty results' do
        expect(resolve_test_runs.items).to be_empty
      end
    end

    context 'when the security policy is not found' do
      let(:policy_hash) do
        {
          policy_index: 999,
          type: 'pipeline_execution_schedule_policy',
          config: policy_configuration
        }
      end

      it 'returns empty results' do
        expect(resolve_test_runs.items).to be_empty
      end
    end

    context 'when multiple inherited schedule policies from different configurations exist' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_policy_management_project) { create(:project) }

      let_it_be(:other_policy_configuration) do
        create(
          :security_orchestration_policy_configuration,
          security_policy_management_project: other_policy_management_project,
          project: other_project
        )
      end

      let_it_be(:other_security_policy) do
        create(:security_policy, :pipeline_execution_schedule_policy,
          name: 'other-test-policy',
          security_orchestration_policy_configuration: other_policy_configuration)
      end

      let_it_be(:test_run_for_policy) do
        create(:security_pipeline_execution_policy_test_run, security_policy: security_policy)
      end

      let_it_be(:test_run_for_other_policy) do
        create(:security_pipeline_execution_policy_test_run, security_policy: other_security_policy)
      end

      it 'returns only the test run belonging to the given policy' do
        policy_hash_one = { policy_index: 0, type: 'pipeline_execution_schedule_policy',
                            config: policy_configuration }
        policy_hash_two = { policy_index: 0, type: 'pipeline_execution_schedule_policy',
                            config: other_policy_configuration }

        result_one = resolve(described_class, obj: policy_hash_one, ctx: ctx).items
        result_two = resolve(described_class, obj: policy_hash_two, ctx: ctx).items

        expect(result_one).to contain_exactly(test_run_for_policy)
        expect(result_two).to contain_exactly(test_run_for_other_policy)
      end
    end
  end
end
