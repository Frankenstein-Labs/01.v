# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'audits security policy branch bypass' do
  let_it_be_with_refind(:merge_request) do
    create(:merge_request, source_branch: 'feature', target_branch: 'main')
  end

  context 'when security policy with branch bypass is present' do
    let_it_be(:security_policy, freeze: false) do
      create(:security_policy, content: {
        bypass_settings: {
          branches: [
            { source: { name: 'feature' }, target: { name: 'main' } }
          ]
        }
      })
    end

    let_it_be(:approval_policy_rule, freeze: false) do
      create(:approval_policy_rule, security_policy: security_policy)
    end

    let_it_be(:approval_rule, freeze: false) do
      create(:approval_merge_request_rule, merge_request: merge_request, approval_policy_rule: approval_policy_rule)
    end

    it 'creates an audit event' do
      expect { execute }.to change { AuditEventReader.count }.by(1)

      event = AuditEventReader.last
      merge_request_reference = "#{merge_request.project.full_path}!#{merge_request.iid}"
      expect(event.details[:custom_message]).to eq(
        "Approvals in merge request (#{merge_request_reference}) with source branch '#{merge_request.source_branch}' " \
          "and target branch '#{merge_request.target_branch}' was bypassed by security policy"
      )
      expect(event.entity).to eq(security_policy.security_policy_management_project)
    end

    it 'tracks internal event', :clean_gitlab_redis_shared_state do
      expect { execute }
        .to trigger_internal_events('check_merge_request_branch_exceptions_bypass')
        .with(project: merge_request.project, additional_properties: { value: merge_request.id })
        .and increment_usage_metrics(
          "redis_hll_counters." \
            "count_distinct_value_from_check_merge_request_branch_exceptions_bypass_monthly"
        )
    end
  end

  context 'when security policy does not exist with branch bypass' do
    it 'does not create an audit event' do
      expect { execute }.not_to change { AuditEventReader.count }
    end

    it 'does not track internal event for branch exceptions bypass' do
      expect { execute }.not_to trigger_internal_events('check_merge_request_branch_exceptions_bypass')
    end
  end
end
