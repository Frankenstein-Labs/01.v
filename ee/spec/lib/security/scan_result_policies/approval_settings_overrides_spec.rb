# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::ApprovalSettingsOverrides, '#all', feature_category: :security_policy_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:security_configuration) { create(:security_orchestration_policy_configuration) }

  let(:warn_mode_policies) { [] }
  let(:enforced_policies) { [] }

  subject(:overrides) do
    described_class
      .new(project: project, warn_mode_policies: warn_mode_policies, enforced_policies: enforced_policies)
      .all
    .map do |override|
      { attribute: override.attribute, policies: override.security_policies.to_a }
    end
  end

  before do
    project.clear_memoization(:merge_requests_author_approval)
    project.clear_memoization(:merge_requests_disable_committers_approval)
    project.clear_memoization(:disable_overriding_approvers_per_merge_request)
  end

  context 'without policies' do
    it { is_expected.to be_empty }
  end

  context 'with restrictive project settings' do
    before do
      project_settings!(
        prevent_approval_by_author: true,
        prevent_approval_by_commit_author: true,
        remove_approvals_with_new_commit: true,
        require_password_to_approve: true)
    end

    let!(:policy_a) { security_policy(1, prevent_approval_by_author: true) }
    let!(:policy_b) { security_policy(2, prevent_approval_by_commit_author: true) }
    let!(:policy_c) { security_policy(3, remove_approvals_with_new_commit: true) }
    let!(:policy_d) { security_policy(4, require_password_to_approve: true) }

    let(:warn_mode_policies) { [policy_a, policy_b, policy_c, policy_d] }

    it { is_expected.to be_empty }
  end

  context 'with restrictive policy approval settings' do
    before do
      project_settings!(
        prevent_approval_by_author: false,
        prevent_approval_by_commit_author: false,
        remove_approvals_with_new_commit: false,
        require_password_to_approve: false)
    end

    let!(:policy_a) { security_policy(1, prevent_approval_by_author: true) }

    let(:warn_mode_policies) { [policy_a] }

    specify do
      expect(overrides).to match_array([
        { attribute: :prevent_approval_by_author, policies: [policy_a] }
      ])
    end
  end

  context 'with overlapped restrictive policy approval settings' do
    before do
      project_settings!(
        prevent_approval_by_author: false,
        prevent_approval_by_commit_author: false,
        remove_approvals_with_new_commit: false,
        require_password_to_approve: false)
    end

    let!(:policy_a) { security_policy(1, prevent_approval_by_author: true) }
    let!(:policy_b) { security_policy(2, prevent_approval_by_author: false) }

    let(:warn_mode_policies) { [policy_a, policy_b] }

    specify do
      expect(overrides).to match_array([
        { attribute: :prevent_approval_by_author, policies: [policy_a] }
      ])
    end
  end

  context 'with mixed settings' do
    before do
      project_settings!(
        prevent_approval_by_author: false,
        prevent_approval_by_commit_author: false,
        remove_approvals_with_new_commit: true,
        require_password_to_approve: false)
    end

    let!(:policy_a) { security_policy(1, prevent_approval_by_author: true, prevent_approval_by_commit_author: true) }
    let!(:policy_b) { security_policy(2, prevent_approval_by_author: true, remove_approvals_with_new_commit: true) }
    let!(:policy_c) { security_policy(3, prevent_approval_by_commit_author: true, require_password_to_approve: true) }
    let!(:policy_d) { security_policy(4, prevent_approval_by_author: false, require_password_to_approve: true) }
    let!(:policy_e) { security_policy(5, remove_approvals_with_new_commit: false) }

    let(:warn_mode_policies) { [policy_a, policy_b, policy_c, policy_d, policy_e] }

    specify do
      expect(overrides).to match_array([
        { attribute: :prevent_approval_by_author, policies: match_array([policy_a, policy_b]) },
        { attribute: :prevent_approval_by_commit_author, policies: match_array([policy_a, policy_c]) },
        { attribute: :require_password_to_approve, policies: match_array([policy_c, policy_d]) }
      ])
    end
  end

  context 'with prevent_editing_approval_rules warn mode policy' do
    before do
      project_settings!(prevent_editing_approval_rules: false)
    end

    let_it_be(:policy_a) { security_policy(1, prevent_editing_approval_rules: true) }
    let(:warn_mode_policies) { [policy_a] }

    specify do
      expect(overrides).to match_array([
        { attribute: :prevent_editing_approval_rules, policies: [policy_a] }
      ])
    end

    context 'when project already restricts editing approval rules' do
      before do
        project_settings!(prevent_editing_approval_rules: true)
      end

      it { is_expected.to be_empty }
    end

    context 'when an enforced policy already sets prevent_editing_approval_rules' do
      let!(:policy_b) { security_policy(2, prevent_editing_approval_rules: true) }
      let(:enforced_policies) { [policy_b] }

      it { is_expected.to be_empty }
    end
  end

  context 'with enforced policies' do
    before do
      project_settings!(
        prevent_approval_by_author: false,
        prevent_approval_by_commit_author: false,
        remove_approvals_with_new_commit: false,
        require_password_to_approve: false)
    end

    let!(:policy_a) { security_policy(1, prevent_approval_by_author: true, require_password_to_approve: false) }
    let!(:policy_b) { security_policy(2, prevent_approval_by_author: false, require_password_to_approve: true) }
    let!(:policy_c) { security_policy(3, prevent_approval_by_author: true) }

    let(:warn_mode_policies) { [policy_a, policy_b] }
    let(:enforced_policies) { [policy_c] }

    specify do
      expect(overrides).to match_array([
        { attribute: :require_password_to_approve, policies: match_array([policy_b]) }
      ])
    end
  end

  private

  def project_settings!(approval_settings)
    project.update!(
      approval_settings.to_h do |attr, val|
        case attr
        when :prevent_approval_by_author then [:merge_requests_author_approval, !val]
        when :prevent_approval_by_commit_author then [:merge_requests_disable_committers_approval, val]
        when :remove_approvals_with_new_commit then [:reset_approvals_on_push, val]
        when :require_password_to_approve then [:require_password_to_approve, val]
        when :prevent_editing_approval_rules then [:disable_overriding_approvers_per_merge_request, val]
        else raise
        end
      end
    )
  end

  def security_policy(policy_index, approval_settings)
    create(:security_policy,
      security_orchestration_policy_configuration: security_configuration,
      policy_index: policy_index,
      content: { approval_settings: approval_settings })
  end
end
