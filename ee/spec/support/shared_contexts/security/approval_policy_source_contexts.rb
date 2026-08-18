# frozen_string_literal: true

RSpec.shared_context 'with approval rule backed by approval_policy_rule' do
  let(:approval_policy_security_policy) do
    existing = approval_policy_source_read.approval_policy_rule&.security_policy&.reload ||
      Security::Policy.find_by(
        security_orchestration_policy_configuration:
          approval_policy_source_read.security_orchestration_policy_configuration,
        policy_index: approval_policy_source_read.orchestration_policy_idx)

    content = try(:approval_policy_security_policy_content) || {}

    if existing
      existing.update_column(:content, content)
      existing.reload
    else
      create(:security_policy, :approval_policy,
        security_orchestration_policy_configuration:
          approval_policy_source_read.security_orchestration_policy_configuration,
        policy_index: approval_policy_source_read.orchestration_policy_idx,
        content: content)
    end
  end

  let(:approval_policy_rule) do
    attrs = { security_policy: approval_policy_security_policy }
    attrs[:content] = approval_policy_rule_content if try(:approval_policy_rule_content)

    existing = approval_policy_source_read.approval_policy_rule
    if existing.present?
      existing.update!(attrs)
      existing.reload
    else
      create(:approval_policy_rule, approval_policy_rule_trait, **attrs)
    end
  end

  before do
    approval_policy_source_read.update!(approval_policy_rule: approval_policy_rule)
    approval_policy_source_rule.update!(approval_policy_rule: approval_policy_rule)
  end
end

RSpec.shared_context 'with divergent fallback_behavior across approval_policy_source' do
  let(:approval_policy_security_policy_content) { { fallback_behavior: { fail: 'open' } } }

  before do
    approval_policy_source_read.update!(fallback_behavior: { fail: 'closed' })
  end
end

RSpec.shared_context 'with divergent vulnerability_age across approval_policy_source' do
  let(:approval_policy_rule_trait) { :scan_finding }
  let(:approval_policy_rule_content) do
    {
      type: 'scan_finding', branches: [],
      scanners: %w[dependency_scanning],
      vulnerabilities_allowed: 0,
      severity_levels: %w[critical],
      vulnerability_states: %w[detected],
      vulnerability_age: { operator: 'greater_than', interval: 'day', value: 10 }
    }
  end

  before do
    approval_policy_source_read.update!(age_operator: 'less_than', age_interval: 'week', age_value: 99)
  end
end

RSpec.shared_context 'with divergent fallback_behavior using existing approval_policy_rule' do
  before do
    approval_policy_source_read.update!(fallback_behavior: { fail: 'closed' })
    approval_policy_source_read.approval_policy_rule.security_policy
      .update!(content: { fallback_behavior: { fail: 'open' } })
  end
end

RSpec.shared_context 'with deprecate_scan_result_policies flag disabled' do
  before do
    stub_feature_flags(deprecate_scan_result_policies: false)
  end
end
