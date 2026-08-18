# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionProjectSchedulePolicy, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:policy_project) { create(:project) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, security_policy_management_project: policy_project)
  end

  let_it_be(:policy) do
    create(:security_policy, :pipeline_execution_schedule_policy,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:schedule) do
    create(:security_pipeline_execution_project_schedule,
      project: project,
      security_policy: policy)
  end

  subject { described_class.new(user, schedule) }

  describe ':read_pipeline_execution_project_schedule' do
    context 'when user can push code to the policy project' do
      let_it_be(:user) { create(:user, developer_of: policy_project) }

      it { expect_allowed(:read_pipeline_execution_project_schedule) }
    end

    context 'when user cannot push code to the policy project' do
      let_it_be(:user) { create(:user) }

      it { expect_disallowed(:read_pipeline_execution_project_schedule) }
    end

    context 'when user has access to target project but not policy project' do
      let_it_be(:user) { create(:user, developer_of: project) }

      it { expect_disallowed(:read_pipeline_execution_project_schedule) }
    end

    context 'when security_policy is nil' do
      let_it_be(:user) { create(:user, developer_of: policy_project) }

      before do
        allow(schedule).to receive(:security_policy).and_return(nil)
      end

      it { expect_disallowed(:read_pipeline_execution_project_schedule) }
    end
  end
end
