# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Merge request > User sees security policy rules license compliance', :with_trial_types,
  :js, :sidekiq_inline, :use_clean_rails_memory_store_caching,
  feature_category: :security_policy_management do
  include Features::SecurityPolicyHelpers

  include_context 'with default organization security policy configuration'

  let_it_be(:project, freeze: false) { create(:project, :repository) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:approver) { create(:user, maintainer_of: project) }
  let_it_be(:approver_roles) { ['maintainer'] }
  let_it_be(:policy_management_project) { create(:project, :repository, creator: user, namespace: project.namespace) }

  let(:policy_hash) do
    build(:approval_policy, name: policy_name,
      actions: [{ type: 'require_approval', approvals_required: 1, role_approvers: approver_roles }],
      rules: [{
        type: 'license_finding',
        branches: policy_branch_names,
        match_on_inclusion_license: true,
        license_types: [license_type],
        license_states: license_states
      }])
  end

  let(:policy_yaml) do
    build(:orchestration_policy_yaml, scan_execution_policy: [], approval_policy: [policy_hash])
  end

  before do
    sign_in(user)
  end

  context 'with license compliance' do
    let_it_be(:ee_merge_request) do
      create(:ee_merge_request, :with_cyclonedx_reports, source_project: project,
        source_branch: 'feature', target_branch: 'master')
    end

    let_it_be(:ee_merge_request_path) { project_merge_request_path(project, ee_merge_request) }
    let(:policy_branch_names) { %w[master] }

    let_it_be(:protected_branch, freeze: false) { create(:protected_branch, name: 'master', project: project) }

    shared_examples 'a merge request without violations' do
      before do
        sign_in(approver)
      end

      it 'does not block the MR', :aggregate_failures do
        visit(ee_merge_request_path)
        wait_for_requests

        expect(page).to have_no_content 'Merge blocked'
        expect(page).to have_content 'Ready to merge!'
        expect(page).to have_button('Merge', exact: true)
      end
    end

    shared_examples 'with approval policy' do
      let_it_be(:existing_license) { create(:pm_license, spdx_identifier: 'MIT') }
      let_it_be(:package) do
        create(:pm_package, name: "activesupport", purl_type: "gem",
          other_licenses: [{ license_names: ["MIT"], versions: ["5.1.4"] }])
      end

      let(:policy_name) { "Deny #{license_type} licenses" }

      context 'when scan result policy for license scanning is not violated' do
        let(:license_type) { 'Apache-2.0' }
        let(:license_states) { %w[newly_detected] }

        before do
          create_policy_setup
        end

        it_behaves_like 'a merge request without violations'
      end

      context 'when scan result policy for license scanning is violated' do
        let(:license_type) { 'MIT' }
        let(:license_states) { %w[newly_detected] }

        before do
          create_policy_setup
        end

        context 'when signed in as user' do
          it 'requires approval', :aggregate_failures,
            quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/9359' do
            visit(ee_merge_request_path)
            wait_for_requests

            expect(page).to have_content "Requires 1 approval from #{policy_name}"
            expect(page).to have_content 'merge request has policy violations and errors'
            expect(page).to have_content 'Merge blocked'
            expect(page).to have_no_button('Merge', exact: true)
          end
        end

        context 'when signed in as maintainer' do
          before do
            sign_in(approver)
          end

          it 'can approve and merge the MR', :aggregate_failures do
            visit(ee_merge_request_path)
            wait_for_requests

            expect(page).to have_content 'Merge blocked'
            expect(page).to have_button('Approve', exact: true)

            click_button 'Approve'
            wait_for_requests
            expect(page).to have_button('Merge', exact: true)
          end
        end
      end

      context 'when scan result policy rule has detected licenses' do
        let(:license_type) { 'MIT' }
        let(:license_states) { %w[detected] }
        let_it_be(:target_pipeline) do
          create(:ee_ci_pipeline, :with_cyclonedx_report, project: project,
            status: :success)
        end

        let(:pipeline_report) { create(:ci_reports_license_scanning_report) }
        let(:sbom_scanner) do
          instance_double(Gitlab::LicenseScanning::SbomScanner,
            report: pipeline_report, results_available?: true, has_data?: true)
        end

        before do
          pipeline_report.add_license(id: license_type, name: license_type).add_dependency(name: package.name)
          allow(::Gitlab::LicenseScanning).to receive(:scanner_for_pipeline)
            .with(project, anything).and_return(sbom_scanner)
          create_policy_setup
        end

        it 'requires approval for detected', :aggregate_failures do
          visit(ee_merge_request_path)
          wait_for_requests

          expect(page).to have_content "Requires 1 approval from #{policy_name}"
          expect(page).to have_content 'merge request has policy violations and errors'
          expect(page).to have_content 'Merge blocked'
        end
      end

      context 'when policy branch is different MR target branch' do
        let(:license_type) { 'MIT' }
        let(:policy_branch_names) { %w[spooky-stuff] }
        let(:license_states) { %w[newly_detected] }

        before do
          create_policy_setup
        end

        it_behaves_like 'a merge request without violations'
      end
    end

    context 'when license scanning feature is not enabled' do
      before do
        stub_licensed_features(license_scanning: false)
      end

      it_behaves_like 'a merge request without violations'
    end

    context 'when license scanning feature is enabled' do
      before do
        stub_licensed_features(license_scanning: true)
      end

      it_behaves_like 'a merge request without violations'
      it_behaves_like 'with approval policy'
    end
  end
end
