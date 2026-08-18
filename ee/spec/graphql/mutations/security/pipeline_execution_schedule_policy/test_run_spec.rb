# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Security::PipelineExecutionSchedulePolicy::TestRun,
  feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:policy_management_project) { create(:project) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration,
      project: project,
      security_policy_management_project: policy_management_project)
  end

  let_it_be(:current_user) { create(:user) }

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  it 'has expected arguments' do
    expect(described_class.arguments.keys).to match_array(
      %w[policyId projectPath clientMutationId]
    )
  end

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields(:test_run, :errors, :client_mutation_id)
  end

  describe '#resolve' do
    let_it_be(:policy) { create(:security_policy, :pipeline_execution_schedule_policy) }
    let(:policy_id) { policy.to_global_id }

    subject(:resolve_mutation) do
      mutation.resolve(policy_id: policy_id, project_path: project.full_path)
    end

    shared_examples_for 'raises a resource not available error' do
      it 'raises a resource not available error' do
        expect { resolve_mutation }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when user does not have access' do
      it_behaves_like 'raises a resource not available error'
    end

    context 'when user has developer access to target project but not policy project' do
      before_all do
        project.add_developer(current_user)
      end

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it_behaves_like 'raises a resource not available error'
    end

    context 'when policy configuration is inherited from group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:group_project) { create(:project, group: group) }
      let_it_be(:group_policy_management_project) { create(:project) }
      let_it_be(:group_policy_configuration) do
        create(:security_orchestration_policy_configuration, :namespace,
          namespace: group,
          security_policy_management_project: group_policy_management_project)
      end

      subject(:resolve_mutation) do
        mutation.resolve(policy_id: policy_id, project_path: group_project.full_path)
      end

      context 'when user has developer access to inherited policy management project' do
        before_all do
          group_project.add_developer(current_user)
          group_policy_management_project.add_developer(current_user)
        end

        let(:test_run) do
          build(:security_pipeline_execution_policy_test_run, project: group_project, state: :pending, pipeline: nil)
        end

        let(:service_result) do
          ServiceResponse.success(payload: { test_run: test_run })
        end

        before do
          stub_licensed_features(security_orchestration_policies: true)

          allow_next_instance_of(::Security::PipelineExecutionPolicies::TestRunService) do |service|
            allow(service).to receive(:execute).and_return(service_result)
          end
        end

        it 'returns the test run in pending state' do
          result = resolve_mutation

          expect(result[:test_run]).to eq(test_run)
          expect(result[:test_run]).to be_pending
          expect(result[:errors]).to be_empty
        end
      end

      context 'when user has developer access to project but not inherited policy management project' do
        before_all do
          group_project.add_developer(current_user)
        end

        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        it_behaves_like 'raises a resource not available error'
      end
    end

    context 'when user has developer access to both target and policy projects' do
      before_all do
        project.add_developer(current_user)
        policy_management_project.add_developer(current_user)
      end

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when project is not found' do
        subject(:resolve_mutation) do
          mutation.resolve(policy_id: policy_id, project_path: 'non/existent')
        end

        it_behaves_like 'raises a resource not available error'
      end

      context 'when policy is not found' do
        let(:policy_id) do
          ::Gitlab::GlobalId.as_global_id(non_existing_record_id, model_name: 'Security::Policy')
        end

        it 'returns an error', :aggregate_failures do
          result = resolve_mutation

          expect(result[:test_run]).to be_nil
          expect(result[:errors]).to include('Policy not found')
        end
      end

      context 'when the service succeeds' do
        let(:test_run) do
          build(:security_pipeline_execution_policy_test_run, project: project, state: :pending, pipeline: nil)
        end

        let(:service_result) do
          ServiceResponse.success(payload: { test_run: test_run })
        end

        before do
          allow_next_instance_of(::Security::PipelineExecutionPolicies::TestRunService) do |service|
            allow(service).to receive(:execute).and_return(service_result)
          end
        end

        it 'returns the test run in pending state' do
          result = resolve_mutation

          expect(result[:test_run]).to eq(test_run)
          expect(result[:test_run]).to be_pending
          expect(result[:errors]).to be_empty
        end
      end

      context 'when the service fails' do
        let(:test_run) { build(:security_pipeline_execution_policy_test_run, project: project) }
        let(:service_result) do
          ServiceResponse.error(message: 'User is not allowed to trigger test runs for this policy',
            payload: { test_run: test_run })
        end

        before do
          allow_next_instance_of(::Security::PipelineExecutionPolicies::TestRunService) do |service|
            allow(service).to receive(:execute).and_return(service_result)
          end
        end

        it 'returns the error message and test run', :aggregate_failures do
          result = resolve_mutation

          expect(result[:test_run]).to eq(test_run)
          expect(result[:errors]).to include('User is not allowed to trigger test runs for this policy')
        end
      end
    end
  end
end
