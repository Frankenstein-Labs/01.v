# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Subscriptions::Security::PolicyScheduleTestRunUpdated, feature_category: :security_policy_management do
  include GraphqlHelpers
  include ::Graphql::Subscriptions::Security::PolicyScheduleTestRunUpdated::Helper

  let_it_be(:policy_project) { create(:project) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration,
      security_policy_management_project: policy_project)
  end

  let_it_be(:policy) do
    create(:security_policy, :pipeline_execution_schedule_policy,
      security_orchestration_policy_configuration: policy_configuration,
      security_policy_management_project: policy_project)
  end

  let_it_be(:target_project) { create(:project) }
  let_it_be_with_reload(:test_run) do
    create(:security_pipeline_execution_policy_test_run,
      project: target_project,
      security_policy: policy,
      state: :running)
  end

  let(:current_user) { nil }
  let(:subscribe) { security_policy_schedule_test_run_updated_subscription(test_run, current_user) }

  before do
    stub_licensed_features(security_orchestration_policies: true)

    stub_const('GitlabSchema', Graphql::Subscriptions::ActionCable::MockGitlabSchema)
    Graphql::Subscriptions::ActionCable::MockActionCable.clear_mocks
  end

  subject(:response) do
    subscription_response do
      GraphqlTriggers.security_policy_schedule_test_run_updated(test_run)
    end
  end

  context 'when unauthorized' do
    it 'does not receive any data' do
      expect(response).to be_nil
    end
  end

  context 'when authorized' do
    let_it_be(:authorized_user) { create(:user, developer_of: policy_project) }
    let(:current_user) { authorized_user }
    let_it_be_with_reload(:other_test_run) do
      create(:security_pipeline_execution_policy_test_run,
        project: target_project,
        security_policy: policy,
        state: :running)
    end

    let(:subscription_data) do
      graphql_dig_at(graphql_data(response[:result]), :securityPolicyScheduleTestRunUpdated)
    end

    it 'receives the updated test run' do
      expect(subscription_data).to include(
        'id' => test_run.to_global_id.to_s,
        'state' => 'RUNNING',
        'completed' => false
      )
    end

    context 'when state transitions to complete' do
      subject(:response) do
        subscription_response do
          test_run.update!(state: :complete)
          GraphqlTriggers.security_policy_schedule_test_run_updated(test_run)
        end
      end

      it 'receives the transitioned state' do
        expect(subscription_data).to include(
          'id' => test_run.to_global_id.to_s,
          'state' => 'COMPLETE',
          'completed' => true
        )
      end
    end

    context 'when update is for a different test run id' do
      subject(:response) do
        subscription_response do
          other_test_run.update!(state: :failed)
          GraphqlTriggers.security_policy_schedule_test_run_updated(other_test_run)
        end
      end

      it 'does not receive any data' do
        expect(response).to be_nil
      end
    end
  end
end
