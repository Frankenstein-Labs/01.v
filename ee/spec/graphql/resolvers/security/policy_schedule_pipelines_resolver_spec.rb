# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::PolicySchedulePipelinesResolver, feature_category: :security_policy_management do
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

  subject(:resolve_schedule_pipelines) { sync(resolve(described_class, obj: policy_hash, ctx: ctx)) }

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
        expect(resolve_schedule_pipelines.items).to be_empty
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
        expect(resolve_schedule_pipelines.items).to be_empty
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
        expect(resolve_schedule_pipelines.items).to be_empty
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
        expect(resolve_schedule_pipelines.items).to be_empty
      end
    end

    context 'when schedule pipelines exist for the policy' do
      let!(:schedule_pipeline) do
        create(:security_policy_schedule_pipeline,
          security_policy: security_policy,
          project: project)
      end

      it 'returns the schedule pipelines' do
        expect(resolve_schedule_pipelines.items).to contain_exactly(schedule_pipeline)
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

      let_it_be(:schedule_pipeline_for_policy) do
        create(:security_policy_schedule_pipeline,
          security_policy: security_policy,
          project: project)
      end

      let_it_be(:schedule_pipeline_for_other_policy) do
        create(:security_policy_schedule_pipeline,
          security_policy: other_security_policy,
          project: other_project)
      end

      let(:policy_hash_one) do
        { policy_index: 0, type: 'pipeline_execution_schedule_policy', config: policy_configuration }
      end

      let(:policy_hash_two) do
        { policy_index: 0, type: 'pipeline_execution_schedule_policy', config: other_policy_configuration }
      end

      it 'returns only the schedule pipelines belonging to the given policy' do
        result_one = sync(resolve(described_class, obj: policy_hash_one, ctx: ctx)).items
        result_two = sync(resolve(described_class, obj: policy_hash_two, ctx: ctx)).items

        expect(result_one).to contain_exactly(schedule_pipeline_for_policy)
        expect(result_two).to contain_exactly(schedule_pipeline_for_other_policy)
      end

      it 'avoids N+1 queries when accessing associations' do
        resolve_both = -> do
          connections = batch_sync do
            [
              resolve(described_class, obj: policy_hash_one, ctx: ctx),
              resolve(described_class, obj: policy_hash_two, ctx: ctx)
            ]
          end
          connections.each do |conn|
            # Only access associations exposed in the GraphQL type: pipeline, project, project.route
            conn.items.each { |sp| [sp.pipeline, sp.project, sp.project.route] }
          end
        end

        resolve_both.call
        control = ActiveRecord::QueryRecorder.new { resolve_both.call }

        create(:security_policy_schedule_pipeline, security_policy: security_policy, project: project)
        create(:security_policy_schedule_pipeline, security_policy: security_policy, project: project)
        create(:security_policy_schedule_pipeline, security_policy: other_security_policy, project: other_project)
        create(:security_policy_schedule_pipeline, security_policy: other_security_policy, project: other_project)

        expect { resolve_both.call }.not_to exceed_query_limit(control)
      end

      it 'bulk-preloads the pipeline association without a per-record query' do
        items = sync(resolve(described_class, obj: policy_hash_one, ctx: ctx)).items

        items.each do |schedule_pipeline|
          expect(schedule_pipeline.association(:pipeline)).to be_loaded
        end

        expect do
          items.each(&:pipeline)
        end.not_to exceed_query_limit(0).for_query(/SELECT.*p_ci_pipelines/)
      end
    end
  end
end
