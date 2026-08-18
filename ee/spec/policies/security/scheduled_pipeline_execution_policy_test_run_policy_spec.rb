# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScheduledPipelineExecutionPolicyTestRunPolicy,
  feature_category: :security_policy_management do
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

  let_it_be(:project) { create(:project) }
  let_it_be(:test_run) do
    create(:security_pipeline_execution_policy_test_run, project: project, security_policy: policy)
  end

  subject { described_class.new(user, test_run) }

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  describe ':read_security_orchestration_policies' do
    context 'when user has developer access to the target project' do
      let_it_be(:user) { create(:user, developer_of: project) }

      it { expect_allowed(:read_security_orchestration_policies) }
    end

    context 'when user has no access' do
      let_it_be(:user) { create(:user) }

      it { expect_disallowed(:read_security_orchestration_policies) }
    end

    context 'when feature is not licensed' do
      let_it_be(:user) { create(:user, developer_of: project) }

      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it { expect_disallowed(:read_security_orchestration_policies) }
    end
  end

  describe ':read_policy_schedule_test_run' do
    context 'when user has developer access to the policy project' do
      let_it_be(:user) { create(:user, developer_of: policy_project) }

      it { expect_allowed(:read_policy_schedule_test_run) }
    end

    context 'when user has no access to the policy project' do
      let_it_be(:user) { create(:user) }

      it { expect_disallowed(:read_policy_schedule_test_run) }
    end

    context 'when user has access to target project but not policy project' do
      let_it_be(:user) { create(:user, developer_of: project) }

      it { expect_disallowed(:read_policy_schedule_test_run) }
    end

    context 'when security_policy is nil' do
      let_it_be(:user) { create(:user, developer_of: project) }

      before do
        allow(test_run).to receive(:security_policy).and_return(nil)
      end

      it { expect_disallowed(:read_policy_schedule_test_run) }
    end
  end

  describe ':create_policy_schedule_test_run' do
    context 'when user has developer access to the policy project' do
      let_it_be(:user) { create(:user, developer_of: policy_project) }

      it { expect_allowed(:create_policy_schedule_test_run) }
    end

    context 'when user has no access to the policy project' do
      let_it_be(:user) { create(:user) }

      it { expect_disallowed(:create_policy_schedule_test_run) }
    end

    context 'when user has access to target project but not policy project' do
      let_it_be(:user) { create(:user, developer_of: project) }

      it { expect_disallowed(:create_policy_schedule_test_run) }
    end

    context 'when security_policy is nil' do
      let_it_be(:user) { create(:user, developer_of: project) }

      before do
        allow(test_run).to receive(:security_policy).and_return(nil)
      end

      it { expect_disallowed(:create_policy_schedule_test_run) }
    end
  end
end
