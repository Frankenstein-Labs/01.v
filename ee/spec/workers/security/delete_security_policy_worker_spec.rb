# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DeleteSecurityPolicyWorker, feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be(:policy) { create(:security_policy) }
    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }
    let_it_be(:license_policy) { create(:software_license_policy, approval_policy_rule: approval_policy_rule) }
    let_it_be(:violation) { create(:scan_result_policy_violation, approval_policy_rule: approval_policy_rule) }

    let_it_be(:approval_project_rule) do
      create(:approval_project_rule,
        security_orchestration_policy_configuration: policy.security_orchestration_policy_configuration,
        approval_policy_rule_id: approval_policy_rule.id
      )
    end

    let_it_be(:approval_merge_request_rule) do
      create(:approval_merge_request_rule,
        security_orchestration_policy_configuration: policy.security_orchestration_policy_configuration,
        approval_policy_rule_id: approval_policy_rule.id
      )
    end

    let(:policy_id) { policy.id }

    subject(:perform) { described_class.new.perform(policy_id) }

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [policy_id] }
    end

    it_behaves_like 'policy metrics with logging', described_class::HISTOGRAM

    context 'when the policy type is scan execution policy' do
      let_it_be(:policy) { create(:security_policy, :scan_execution_policy) }
      let_it_be(:scan_execution_policy_rule) { create(:scan_execution_policy_rule, security_policy: policy) }

      it 'deletes the security policy and associated records' do
        expect { perform }.to change { Security::ScanExecutionPolicyRule.count }.by(-1)
          .and change { Security::Policy.count }.by(-1)
      end
    end

    context 'when the policy type is pipeline_execution_schedule_policy' do
      let_it_be(:policy) { create(:security_policy, :pipeline_execution_schedule_policy) }
      let_it_be(:schedule) { create(:security_pipeline_execution_project_schedule, security_policy: policy) }

      before do
        allow_next_found_instance_of(Security::Policy) do |security_policy|
          allow(security_policy).to receive(:delete)
        end
      end

      it 'deletes the security policy and associated records' do
        expect { perform }.to change { Security::PipelineExecutionProjectSchedule.count }.by(-1)
      end
    end

    context 'when the security policy exists' do
      it 'deletes the security policy and associated records' do
        expect { perform }.to change { ApprovalProjectRule.count }.by(-1)
          .and change { ApprovalMergeRequestRule.count }.by(-1)
          .and change { Security::ScanResultPolicyViolation.count }.by(-1)
          .and change { SoftwareLicensePolicy.count }.by(-1)
          .and change { Security::ApprovalPolicyRule.count }.by(-1)
          .and change { Security::Policy.count }.by(-1)
      end
    end

    context 'when the security policy does not exist' do
      let(:policy_id) { non_existing_record_id }

      it 'does not perform any deletes' do
        expect { perform }.not_to change { Security::Policy.count }
      end
    end
  end
end
