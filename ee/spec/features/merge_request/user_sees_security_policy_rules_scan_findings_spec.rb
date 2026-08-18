# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Merge request > User sees security policy with scan finding rule',
  :js, :sidekiq_inline, :use_clean_rails_memory_store_caching,
  feature_category: :security_policy_management do
  include Features::SecurityPolicyHelpers

  include_context 'with default organization security policy configuration'

  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:user) { project.creator }
  let_it_be(:bot_user) { ::Users::Internal.in_organization(project.organization).security_bot }
  let_it_be(:policy_management_project) { create(:project, :repository, creator: user, namespace: project.namespace) }
  let_it_be(:mr_params) do
    {
      title: 'MR to test scan result policy',
      target_branch: project.default_branch,
      source_branch: 'feature'
    }
  end

  let(:merge_request) do
    ::MergeRequests::CreateService.new(project: project,
      current_user: user,
      params: mr_params).execute
  end

  let(:merge_request_path) { project_merge_request_path(project, merge_request) }

  let_it_be(:approver) { create(:user, maintainer_of: project) }
  let_it_be(:approver_roles) { ['maintainer'] }
  let!(:protected_branch) { create(:protected_branch, project: project, name: merge_request.target_branch) }
  let(:vuln_states) { [] }

  let(:policy_rule) do
    {
      type: 'scan_finding',
      scanners: scanners,
      vulnerabilities_allowed: 0,
      severity_levels: severity_levels,
      vulnerability_states: vuln_states,
      branches: %w[master]
    }
  end

  let(:policy_hash) do
    build(:approval_policy, name: policy_name,
      actions: [{ type: 'require_approval', approvals_required: 1, role_approvers: approver_roles }],
      rules: [policy_rule])
  end

  let(:policy_yaml) do
    build(:orchestration_policy_yaml, scan_execution_policy: [], approval_policy: [policy_hash])
  end

  before_all do
    project.add_developer(user)
  end

  context 'with scan findings' do
    let(:policy_name) { "Spooky_policy" }
    let!(:pipeline_scan) do
      create(:security_scan, :succeeded, project: project, pipeline: pipeline, scan_type: 'sast')
    end

    let(:severity_levels) { [] }
    let(:branch_ref) { merge_request.source_branch }
    let(:sha) { merge_request.diff_head_sha }
    let!(:pipeline) do
      create(:ee_ci_pipeline, :success, :with_sast_report, merge_requests_as_head_pipeline: [merge_request],
        project: project, ref: branch_ref, sha: sha).tap do |p|
        pipeline_scan = create(:security_scan, :succeeded, project: project, pipeline: p, scan_type: 'sast')
        create(:security_finding, severity: 'high', scan: pipeline_scan)
      end
    end

    let!(:target_pipeline) do
      create(:ee_ci_pipeline, :success, :with_sast_report,
        project: project, ref: project.default_branch, sha: merge_request.diff_base_sha)
    end

    let!(:target_pipeline_scan) do
      create(:security_scan, :succeeded, project: project, pipeline: target_pipeline, scan_type: 'sast')
    end

    before do
      sign_in(user)
    end

    shared_examples 'blocks the MR' do
      it 'merge blocked text is present' do
        visit(merge_request_path)
        wait_for_requests
        expect(page).to have_content 'Merge blocked'
      end
    end

    shared_examples 'does not block the MR' do
      it 'merge blocked text is not present', :aggregate_failures do
        visit(merge_request_path)
        wait_for_requests
        expect(page).to have_no_content 'Merge blocked'
        expect(page).to have_button('Merge', exact: true)
      end
    end

    context 'when scanner from pipeline matches the policy' do
      let(:scanners) { %w[sast] }

      before do
        create_policy_setup
      end

      it_behaves_like 'blocks the MR'
    end

    context 'with severity level defined' do
      let(:scanners) { %w[sast] }

      context 'when it matches with policy' do
        let(:severity_levels) { %w[critical high] }

        before do
          create_policy_setup
        end

        it_behaves_like 'blocks the MR'
      end

      context 'when it differs from policy' do
        let(:severity_levels) { %w[low] }

        before do
          create_policy_setup
        end

        it_behaves_like 'does not block the MR'
      end
    end

    context 'when scanner from pipeline does not match the policy' do
      let(:scanners) { %w[dast] }

      before do
        create_policy_setup
      end

      it_behaves_like 'does not block the MR'
    end

    context 'when there is no target pipeline' do
      let(:target_pipeline) { nil }
      let(:scanners) { %w[sast] }

      before do
        create_policy_setup
      end

      it_behaves_like 'blocks the MR'
    end

    context 'when policy is defined for protected branches using branch_type' do
      let(:scanners) { %w[sast] }
      let(:policy_rule) do
        {
          type: 'scan_finding',
          scanners: scanners,
          vulnerabilities_allowed: 0,
          severity_levels: severity_levels,
          vulnerability_states: vuln_states,
          branch_type: 'protected'
        }
      end

      before do
        create_policy_setup
      end

      it_behaves_like 'blocks the MR'
    end

    context 'when policy is defined for pre-existing vulnerabilities' do
      let(:scanners) { %w[sast] }
      let(:vuln_states) { %w[detected] }

      before do
        allow(::Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker).to receive(:perform_async)
        create(:vulnerabilities_finding, :detected, project: project)
        create_policy_setup
      end

      it_behaves_like 'blocks the MR'
    end
  end
end
