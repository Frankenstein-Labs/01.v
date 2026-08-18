# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PipelineFailedAuditor, feature_category: :security_policy_management do
  it_behaves_like 'pipeline auditor' do
    let(:event_name) { 'security_policy_pipeline_failed' }
    let(:event_message) { "Pipeline: #{pipeline.id} created by security policies or with security policy jobs failed" }
  end
end
