# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PipelineSkippedAuditor, feature_category: :security_policy_management do
  it_behaves_like 'pipeline auditor' do
    let(:event_name) { 'security_policy_pipeline_skipped' }
    let(:event_message) { "Pipeline: #{pipeline.id} with security policy jobs skipped" }
  end
end
