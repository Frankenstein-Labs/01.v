# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ApprovalPolicyFiltering, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }

  let(:rule) do
    create(:report_approver_rule, :scan_finding, merge_request: merge_request)
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)
    allow(project).to receive_messages(
      merge_requests_author_approval?: true,
      merge_requests_disable_committers_approval?: false
    )
  end

  describe '#prevents_author_approval?' do
    context 'when approval_policy_source is nil' do
      it 'returns false' do
        expect(rule.prevents_author_approval?).to be(false)
      end
    end

    context 'when approval_policy_source prevents author approval' do
      let(:rule) do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request,
          scan_result_policy_read: create(:scan_result_policy_read, project: project,
            project_approval_settings: { 'prevent_approval_by_author' => true }))
      end

      it 'returns true' do
        expect(rule.prevents_author_approval?).to be(true)
      end
    end

    context 'when approval_policy_source does not prevent author approval' do
      let(:rule) do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request,
          scan_result_policy_read: create(:scan_result_policy_read, project: project,
            project_approval_settings: { 'prevent_approval_by_author' => false }))
      end

      it 'returns false' do
        expect(rule.prevents_author_approval?).to be(false)
      end
    end
  end

  describe '#prevents_committer_approval?' do
    context 'when approval_policy_source is nil' do
      it 'returns false' do
        expect(rule.prevents_committer_approval?).to be(false)
      end
    end

    context 'when approval_policy_source prevents committer approval' do
      let(:rule) do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request,
          scan_result_policy_read: create(:scan_result_policy_read, project: project,
            project_approval_settings: { 'prevent_approval_by_commit_author' => true }))
      end

      it 'returns true' do
        expect(rule.prevents_committer_approval?).to be(true)
      end
    end

    context 'when approval_policy_source does not prevent committer approval' do
      let(:rule) do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request,
          scan_result_policy_read: create(:scan_result_policy_read, project: project,
            project_approval_settings: { 'prevent_approval_by_commit_author' => false }))
      end

      it 'returns false' do
        expect(rule.prevents_committer_approval?).to be(false)
      end
    end
  end
end
