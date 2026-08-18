# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicySchedulePipelinePolicy, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:policy_project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, security_policy_management_project: policy_project)
  end

  let_it_be(:policy) do
    create(:security_policy, :pipeline_execution_schedule_policy,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:schedule_pipeline) do
    create(:security_policy_schedule_pipeline,
      project: project,
      pipeline: pipeline,
      security_policy: policy)
  end

  subject { described_class.new(user, schedule_pipeline) }

  describe ':read_policy_schedule_pipeline' do
    context 'when user can push code to the policy project' do
      let_it_be(:user) { create(:user, developer_of: policy_project) }

      it { expect_allowed(:read_policy_schedule_pipeline) }
    end

    context 'when user cannot push code to the policy project' do
      let_it_be(:user) { create(:user) }

      it { expect_disallowed(:read_policy_schedule_pipeline) }
    end

    context 'when user has access to target project but not policy project' do
      let_it_be(:user) { create(:user, developer_of: project) }

      it { expect_disallowed(:read_policy_schedule_pipeline) }
    end
  end
end
