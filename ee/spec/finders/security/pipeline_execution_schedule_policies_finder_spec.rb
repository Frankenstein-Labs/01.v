# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionSchedulePoliciesFinder, feature_category: :security_policy_management do
  let!(:policy) do
    build(:pipeline_execution_schedule_policy, name: 'Contains scheduled pipeline configuration',
      policy_scope: policy_scope)
  end

  let!(:policy_yaml) do
    build(:orchestration_policy_yaml, pipeline_execution_schedule_policy: [policy])
  end

  let(:expected_extra_attrs) { { type: 'pipeline_execution_schedule_policy', policy_index: 0 } }

  include_context 'with security policies information'

  it_behaves_like 'security policies finder'
end
