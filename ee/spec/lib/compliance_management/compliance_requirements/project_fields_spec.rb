# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceRequirements::ProjectFields, feature_category: :compliance_management do
  include ProjectForksHelper

  let_it_be(:namespace) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, namespace: namespace) }
  let_it_be(:group) { create(:group) }
  let_it_be(:group_project) { create(:project, namespace: group) }

  describe '.map_field' do
    before do
      allow(ComplianceManagement::ComplianceFramework::Controls::Registry).to receive(:field_mappings)
        .and_return(
          'default_branch_protected' => :default_branch_protected?,
          'merge_request_prevent_author_approval' => :merge_request_prevent_author_approval?,
          'merge_request_prevent_committers_approval' => :merge_requests_disable_committers_approval?,
          'project_visibility' => :project_visibility,
          'minimum_approvals_required' => :minimum_approvals_required,
          'auth_sso_enabled' => :auth_sso_enabled?,
          'scanner_sast_running' => :scanner_sast_running?,
          'scanner_secret_detection_running' => :scanner_secret_detection_running?,
          'scanner_dep_scanning_running' => :scanner_dep_scanning_running?,
          'scanner_container_scanning_running' => :scanner_container_scanning_running?,
          'scanner_license_compliance_running' => :scanner_license_compliance_running?,
          'scanner_dast_running' => :scanner_dast_running?,
          'scanner_api_security_running' => :scanner_api_security_running?,
          'scanner_code_quality_running' => :scanner_code_quality_running?,
          'scanner_iac_running' => :scanner_iac_running?,
          'terraform_enabled' => :terraform_enabled?,
          'gitlab_license_level_ultimate' => :gitlab_license_level_ultimate?,
          'status_page_configured' => :status_page_configured?,
          'has_valid_ci_config' => :has_valid_ci_config?,
          'error_tracking_enabled' => :error_tracking_enabled?,
          'default_branch_users_can_push' => :default_branch_users_can_push?,
          'default_branch_protected_from_direct_push' => :default_branch_protected_from_direct_push?
        )

      allow(project).to receive(:default_branch).and_return('main')
    end

    it 'defines expected field mappings from Registry' do
      expect(described_class::FIELD_MAPPINGS.keys).to contain_exactly(
        'default_branch_protected',
        'merge_request_prevent_author_approval',
        'merge_request_prevent_committers_approval',
        'project_visibility_not_internal',
        'minimum_approvals_required',
        'auth_sso_enabled',
        'scanner_sast_running',
        'scanner_secret_detection_running',
        'scanner_dep_scanning_running',
        'scanner_container_scanning_running',
        'scanner_license_compliance_running',
        'scanner_dast_running',
        'scanner_api_security_running',
        'scanner_code_quality_running',
        'scanner_iac_running',
        'project_repo_exists',
        'issue_tracking_enabled',
        'code_changes_requires_code_owners',
        'stale_branch_cleanup_enabled',
        'reset_approvals_on_push',
        'protected_branches_set',
        'code_owner_approval_required',
        'status_checks_required',
        'require_branch_up_to_date',
        'resolve_discussions_required',
        'require_signed_commits',
        'require_linear_history',
        'restrict_push_merge_access',
        'force_push_disabled',
        'terraform_enabled',
        'branch_deletion_disabled',
        'has_forks',
        'review_and_archive_stale_repos',
        'review_and_remove_inactive_users',
        'more_members_than_admins',
        'require_mfa_for_contributors',
        'require_mfa_at_org_level',
        'ensure_2_admins_per_repo',
        'strict_permissions_for_repo',
        'secure_webhooks',
        'restricted_build_access',
        'gitlab_license_level_ultimate',
        'status_page_configured',
        'has_valid_ci_config',
        'error_tracking_enabled',
        'default_branch_users_can_push',
        'default_branch_protected_from_direct_push',
        "push_protection_enabled",
        "project_marked_for_deletion",
        "project_archived",
        "default_branch_users_can_merge",
        "merge_request_commit_reset_approvals",
        "project_visibility_not_public",
        "package_hunter_no_findings_untriaged",
        "project_pipelines_not_public",
        "vulnerabilities_slo_days_over_threshold",
        "merge_requests_approval_rules_prevent_editing",
        "project_user_defined_variables_restricted_to_maintainers",
        "merge_requests_require_code_owner_approval",
        "cicd_job_token_scope_enabled"
      )
    end

    it 'returns nil for unknown fields' do
      expect(described_class.map_field(project, 'unknown_field')).to be_nil
    end

    describe 'default_branch_protected' do
      it 'calls ProtectedBranch#protected?' do
        expect(ProtectedBranch).to receive(:protected?).with(project, project.default_branch)

        described_class.map_field(project, 'default_branch_protected')
      end

      context 'when default_branch is nil' do
        let(:project_without_default_branch) { build_stubbed(:project) }

        before do
          allow(project_without_default_branch).to receive(:default_branch).and_return(nil)
        end

        it 'returns false' do
          expect(described_class.map_field(project_without_default_branch, 'default_branch_protected')).to be false
        end
      end
    end

    describe 'merge_request_prevent_author_approval' do
      context 'without approval settings' do
        it 'calls merge_requests_author_approval? on project' do
          expect(project).to receive(:merge_requests_author_approval?)

          described_class.map_field(project, 'merge_request_prevent_author_approval')
        end

        it 'returns true when project has author approval disabled' do
          allow(project).to receive(:merge_requests_author_approval?).and_return(false)

          result = described_class.map_field(project, 'merge_request_prevent_author_approval')

          expect(result).to be true
        end

        it 'returns false when project has author approval enabled' do
          allow(project).to receive(:merge_requests_author_approval?).and_return(true)

          result = described_class.map_field(project, 'merge_request_prevent_author_approval')

          expect(result).to be false
        end
      end

      context 'with approval settings' do
        context 'when approval settings is empty' do
          let(:approval_settings) { [] }

          it 'returns based on project setting only' do
            allow(project).to receive(:merge_requests_author_approval?).and_return(false)
            expect(described_class.map_field(project, 'merge_request_prevent_author_approval',
              { approval_settings: approval_settings })).to be true

            allow(project).to receive(:merge_requests_author_approval?).and_return(true)
            expect(described_class.map_field(project, 'merge_request_prevent_author_approval',
              { approval_settings: approval_settings })).to be false
          end
        end

        context 'when settings include prevent_approval_by_author set to false' do
          let(:approval_settings) do
            [{ "prevent_approval_by_author" => false }]
          end

          it 'returns based on project setting only' do
            allow(project).to receive(:merge_requests_author_approval?).and_return(false)
            expect(described_class.map_field(project, 'merge_request_prevent_author_approval',
              { approval_settings: approval_settings })).to be true

            allow(project).to receive(:merge_requests_author_approval?).and_return(true)
            expect(described_class.map_field(project, 'merge_request_prevent_author_approval',
              { approval_settings: approval_settings })).to be false
          end
        end

        context 'when settings include preventing author approval' do
          let(:approval_settings) do
            [{ "prevent_approval_by_author" => true }]
          end

          it 'returns true regardless of project setting' do
            allow(project).to receive(:merge_requests_author_approval?).and_return(true)

            result = described_class.map_field(project, 'merge_request_prevent_author_approval',
              { approval_settings: approval_settings })

            expect(result).to be true
          end
        end

        context 'when settings do not include preventing author approval' do
          let(:approval_settings) do
            [{ "some_other_setting" => true }]
          end

          it 'returns true if project prevents author approval' do
            allow(project).to receive(:merge_requests_author_approval?).and_return(false)

            result = described_class.map_field(project, 'merge_request_prevent_author_approval',
              { approval_settings: approval_settings })

            expect(result).to be true
          end

          it 'returns false if project allows author approval' do
            allow(project).to receive(:merge_requests_author_approval?).and_return(true)

            result = described_class.map_field(project, 'merge_request_prevent_author_approval',
              { approval_settings: approval_settings })

            expect(result).to be false
          end
        end
      end
    end

    describe 'merge_request_prevent_committers_approval' do
      context 'without approval settings' do
        it 'calls merge_requests_disable_committers_approval? on project' do
          expect(project).to receive(:merge_requests_disable_committers_approval?)

          described_class.map_field(project, 'merge_request_prevent_committers_approval')
        end

        it 'returns true when project prevents committer approval' do
          allow(project).to receive(:merge_requests_disable_committers_approval?).and_return(true)

          result = described_class.map_field(project, 'merge_request_prevent_committers_approval')

          expect(result).to be true
        end

        it 'returns false when project allows committer approval' do
          allow(project).to receive(:merge_requests_disable_committers_approval?).and_return(false)

          result = described_class.map_field(project, 'merge_request_prevent_committers_approval')

          expect(result).to be false
        end
      end

      context 'with approval settings' do
        context 'when approval settings is empty' do
          let(:approval_settings) { [] }

          it 'returns based on project setting only' do
            allow(project).to receive(:merge_requests_disable_committers_approval?).and_return(true)
            expect(described_class.map_field(project, 'merge_request_prevent_committers_approval',
              { approval_settings: approval_settings })).to be true

            allow(project).to receive(:merge_requests_disable_committers_approval?).and_return(false)
            expect(described_class.map_field(project, 'merge_request_prevent_committers_approval',
              { approval_settings: approval_settings })).to be false
          end
        end

        context 'when settings include prevent_approval_by_commit_author set to false' do
          let(:approval_settings) do
            [{ "prevent_approval_by_commit_author" => false }]
          end

          it 'returns based on project setting only' do
            allow(project).to receive(:merge_requests_disable_committers_approval?).and_return(true)
            expect(described_class.map_field(project, 'merge_request_prevent_committers_approval',
              { approval_settings: approval_settings })).to be true

            allow(project).to receive(:merge_requests_disable_committers_approval?).and_return(false)
            expect(described_class.map_field(project, 'merge_request_prevent_committers_approval',
              { approval_settings: approval_settings })).to be false
          end
        end

        context 'when settings include preventing committer approval' do
          let(:approval_settings) do
            [{ "prevent_approval_by_commit_author" => true }]
          end

          it 'returns true regardless of project setting' do
            allow(project).to receive(:merge_requests_disable_committers_approval?).and_return(false)

            result = described_class.map_field(project, 'merge_request_prevent_committers_approval',
              { approval_settings: approval_settings })

            expect(result).to be true
          end
        end

        context 'when settings do not include preventing committer approval' do
          let(:approval_settings) do
            [{ "some_other_setting" => true }]
          end

          it 'returns true if project prevents committer approval' do
            allow(project).to receive(:merge_requests_disable_committers_approval?).and_return(true)

            result = described_class.map_field(project, 'merge_request_prevent_committers_approval',
              { approval_settings: approval_settings })

            expect(result).to be true
          end

          it 'returns false if project allows committer approval' do
            allow(project).to receive(:merge_requests_disable_committers_approval?).and_return(false)

            result = described_class.map_field(project, 'merge_request_prevent_committers_approval',
              { approval_settings: approval_settings })

            expect(result).to be false
          end
        end
      end
    end

    describe 'minimum_approvals_required' do
      it 'calls pick on project approval rules' do
        expect(project.approval_rules).to receive(:pick).with("SUM(approvals_required)")

        described_class.map_field(project, 'minimum_approvals_required')
      end

      context 'when no approval rules exist' do
        before do
          allow(project.approval_rules).to receive(:pick).and_return(nil)
        end

        it 'returns 0' do
          expect(described_class.map_field(project, 'minimum_approvals_required')).to eq(0)
        end
      end
    end

    describe 'auth_sso_enabled' do
      before do
        allow(project).to receive(:group).and_return(namespace)
      end

      it 'calls Groups::SsoHelper.saml_provider_enabled? with project.group' do
        expect(::Groups::SsoHelper).to receive(:saml_provider_enabled?).with(project.group)

        described_class.map_field(project, 'auth_sso_enabled')
      end

      context 'when SAML provider is enabled' do
        before do
          allow(::Groups::SsoHelper).to receive(:saml_provider_enabled?).with(project.group).and_return(true)
        end

        it 'returns true' do
          expect(described_class.map_field(project, 'auth_sso_enabled')).to be true
        end
      end

      context 'when SAML provider is not enabled' do
        before do
          allow(::Groups::SsoHelper).to receive(:saml_provider_enabled?).with(project.group).and_return(false)
        end

        it 'returns false' do
          expect(described_class.map_field(project, 'auth_sso_enabled')).to be false
        end
      end

      context 'when project has no group' do
        let_it_be(:project_without_group) { create(:project) }

        it 'returns false' do
          expect(described_class.map_field(project_without_group, 'auth_sso_enabled')).to be false
        end
      end
    end

    describe 'scanner_sast_running' do
      it 'calls security_scanner_running? with scanner type sast' do
        expect(described_class).to receive(:security_scanner_running?).with(:sast, project, {})

        described_class.map_field(project, 'scanner_sast_running')
      end
    end

    describe 'scanner_secret_detection_running' do
      it 'calls security_scanner_running? with scanner type secret_detection' do
        expect(described_class).to receive(:security_scanner_running?).with(:secret_detection, project, {})

        described_class.map_field(project, 'scanner_secret_detection_running')
      end
    end

    describe 'scanner_dep_scanning_running' do
      it 'calls security_scanner_running? with scanner type dependency_scanning' do
        expect(described_class).to receive(:security_scanner_running?).with(:dependency_scanning, project, {})

        described_class.map_field(project, 'scanner_dep_scanning_running')
      end
    end

    describe 'scanner_container_scanning_running' do
      it 'calls security_scanner_running? with scanner type container_scanning' do
        expect(described_class).to receive(:security_scanner_running?).with(:container_scanning, project, {})

        described_class.map_field(project, 'scanner_container_scanning_running')
      end
    end

    describe 'scanner_license_compliance_running' do
      it 'calls security_scanner_running? with scanner type dependency_scanning' do
        expect(described_class).to receive(:security_scanner_running?).with(:dependency_scanning, project, {})

        described_class.map_field(project, 'scanner_license_compliance_running')
      end
    end

    describe 'scanner_dast_running' do
      it 'calls security_scanner_running? with scanner type dast' do
        expect(described_class).to receive(:security_scanner_running?).with(:dast, project, {})

        described_class.map_field(project, 'scanner_dast_running')
      end
    end

    describe 'scanner_api_security_running' do
      it 'returns true when api_fuzzing scanner is running' do
        allow(described_class).to receive(:security_scanner_running?).with(:api_fuzzing, project, {}).and_return(true)
        allow(described_class).to receive(:security_scanner_running?).with(:dast, project, {}).and_return(false)

        expect(described_class.map_field(project, 'scanner_api_security_running')).to be true
      end

      it 'returns true when dast scanner is running' do
        allow(described_class).to receive(:security_scanner_running?).with(:api_fuzzing, project, {}).and_return(false)
        allow(described_class).to receive(:security_scanner_running?).with(:dast, project, {}).and_return(true)

        expect(described_class.map_field(project, 'scanner_api_security_running')).to be true
      end

      it 'returns true when both api_fuzzing and dast scanners are running' do
        allow(described_class).to receive(:security_scanner_running?).with(:api_fuzzing, project, {}).and_return(true)
        allow(described_class).to receive(:security_scanner_running?).with(:dast, project, {}).and_return(true)

        expect(described_class.map_field(project, 'scanner_api_security_running')).to be true
      end

      it 'returns false when neither api_fuzzing nor dast scanners are running' do
        allow(described_class).to receive(:security_scanner_running?).with(:api_fuzzing, project, {}).and_return(false)
        allow(described_class).to receive(:security_scanner_running?).with(:dast, project, {}).and_return(false)

        expect(described_class.map_field(project, 'scanner_api_security_running')).to be false
      end
    end

    describe 'scanner_code_quality_running' do
      it 'calls security_scanner_running? with scanner type code_quality' do
        expect(described_class).to receive(:security_scanner_running?).with(:codequality, project, {})

        described_class.map_field(project, 'scanner_code_quality_running')
      end
    end

    describe 'security_scanner_running?' do
      let_it_be(:pipeline) { create(:ci_pipeline, :success, project: project) }
      let_it_be(:build) { create(:ci_build, :secret_detection_report, :success, pipeline: pipeline, project: project) }

      before do
        allow(project).to receive(:latest_pipeline_for_ci_and_security_orchestration)
          .and_return(pipeline)
      end

      it 'returns true if the latest successful pipeline has the scanner job artifact' do
        expect(described_class.send(:security_scanner_running?, :secret_detection, project)).to be true
      end

      it 'returns false if the latest successful pipeline does not have the scanner job artifact' do
        expect(described_class.send(:security_scanner_running?, :sast, project)).to be false
      end

      it 'returns false if the scanner is not supported' do
        expect(described_class.send(:security_scanner_running?, :foo, project)).to be false
      end

      it 'returns false if there is no latest successful pipeline' do
        project = create(:project, namespace: namespace)
        allow(project).to receive(:latest_pipeline_for_ci_and_security_orchestration).and_return(nil)

        expect(described_class.send(:security_scanner_running?, :secret_detection, project)).to be false
      end

      it 'returns true if the latest pipeline has the scanner job artifact even when pipeline failed' do
        project = create(:project, namespace: namespace)
        pipeline = create(:ci_pipeline, :failed, project: project)
        create(:ci_build, :secret_detection_report, :success, pipeline: pipeline, project: project)
        allow(project).to receive(:latest_pipeline_for_ci_and_security_orchestration).and_return(pipeline)

        expect(described_class.send(:security_scanner_running?, :secret_detection, project)).to be true
      end

      it 'returns true if the latest pipeline has the scanner job artifact even when pipeline was cancelled' do
        project = create(:project, namespace: namespace)
        pipeline = create(:ci_pipeline, :canceled, project: project)
        create(:ci_build, :secret_detection_report, :success, pipeline: pipeline, project: project)
        allow(project).to receive(:latest_pipeline_for_ci_and_security_orchestration).and_return(pipeline)

        expect(described_class.send(:security_scanner_running?, :secret_detection, project)).to be true
      end

      it 'returns false if the project has a successful pipeline with a job artifact for a non-default branch' do
        project = create(:project, :small_repo, namespace: namespace)
        pipeline = create(:ci_pipeline, :success, project: project, ref: 'non-default')
        create(:ci_build, :secret_detection_report, :success, pipeline: pipeline, project: project)
        allow(project).to receive(:latest_pipeline_for_ci_and_security_orchestration).and_return(nil)

        expect(described_class.send(:security_scanner_running?, :secret_detection, project)).to be false
      end

      it 'returns true if the latest pipeline from security_orchestration_policy has the scanner job artifact' do
        project = create(:project, :small_repo, namespace: namespace)
        pipeline = create(:ci_pipeline, :success, project: project, ref: project.default_branch,
          source: :security_orchestration_policy)
        create(:ci_build, :secret_detection_report, :success, pipeline: pipeline, project: project)
        allow(project).to receive(:latest_pipeline_for_ci_and_security_orchestration).and_return(pipeline)

        expect(described_class.send(:security_scanner_running?, :secret_detection, project)).to be true
      end

      it 'returns false if only parent_pipeline exists with scanner artifacts' do
        project = create(:project, :small_repo, namespace: namespace)
        pipeline = create(:ci_pipeline, :success, project: project, ref: project.default_branch,
          source: :parent_pipeline)
        create(:ci_build, :secret_detection_report, :success, pipeline: pipeline, project: project)
        allow(project).to receive(:latest_pipeline_for_ci_and_security_orchestration).and_return(nil)

        expect(described_class.send(:security_scanner_running?, :secret_detection, project)).to be false
      end

      it 'returns false if only webide pipeline exists with scanner artifacts' do
        project = create(:project, :small_repo, namespace: namespace)
        pipeline = create(:ci_pipeline, :success, project: project, ref: project.default_branch,
          source: :webide)
        create(:ci_build, :secret_detection_report, :success, pipeline: pipeline, project: project)
        allow(project).to receive(:latest_pipeline_for_ci_and_security_orchestration).and_return(nil)

        expect(described_class.send(:security_scanner_running?, :secret_detection, project)).to be false
      end
    end

    describe 'scanner_iac_running' do
      let_it_be(:pipeline) { create(:ci_pipeline, :success, project: project) }

      before do
        allow(project.ci_pipelines)
          .to receive(:newest_first)
          .with(ref: project.default_branch)
          .and_return(Ci::Pipeline.where(id: pipeline.id))
      end

      context 'when pipeline is nil' do
        before do
          allow(project.ci_pipelines)
            .to receive(:newest_first)
            .with(ref: project.default_branch)
            .and_return(Ci::Pipeline.none)
        end

        it 'returns false' do
          expect(described_class.map_field(project, 'scanner_iac_running')).to be false
        end
      end

      context 'when kics-iac-sast job exists' do
        let_it_be(:iac_build) { create(:ci_build, name: 'kics-iac-sast', pipeline: pipeline, project: project) }

        context 'with SAST artifacts' do
          before do
            create(:ci_job_artifact, :sast, job: iac_build, project: project)
          end

          it 'returns true' do
            expect(described_class.map_field(project, 'scanner_iac_running')).to be true
          end
        end

        context 'without SAST artifacts' do
          it 'returns false' do
            expect(described_class.map_field(project, 'scanner_iac_running')).to be false
          end
        end
      end

      context 'when kics-iac-sast job does not exist' do
        it 'returns false' do
          expect(described_class.map_field(project, 'scanner_iac_running')).to be false
        end
      end

      context 'when non-IaC job has SAST artifacts' do
        let_it_be(:random_build) { create(:ci_build, name: 'some-other-job', pipeline: pipeline, project: project) }

        before do
          create(:ci_job_artifact, :sast, job: random_build, project: project)
        end

        it 'returns false because job name does not match IaC pattern' do
          expect(described_class.map_field(project, 'scanner_iac_running')).to be false
        end
      end

      context 'when pipeline failed but has SAST artifacts' do
        let_it_be(:pipeline) { create(:ci_pipeline, :failed, project: project) }
        let_it_be(:iac_build) { create(:ci_build, name: 'kics-iac-sast', pipeline: pipeline, project: project) }

        before do
          create(:ci_job_artifact, :sast, job: iac_build, project: project)
        end

        it 'returns true' do
          expect(described_class.map_field(project, 'scanner_iac_running')).to be true
        end
      end

      context 'when kics-iac-sast job with SEP suffix exists' do
        let_it_be(:iac_build) { create(:ci_build, name: 'kics-iac-sast-0', pipeline: pipeline, project: project) }

        context 'with SAST artifacts' do
          before do
            create(:ci_job_artifact, :sast, job: iac_build, project: project)
          end

          it 'returns true' do
            expect(described_class.map_field(project, 'scanner_iac_running')).to be true
          end
        end

        context 'without SAST artifacts' do
          it 'returns false' do
            expect(described_class.map_field(project, 'scanner_iac_running')).to be false
          end
        end
      end

      context 'when multiple SEP IaC jobs exist' do
        let_it_be(:iac_build_0) { create(:ci_build, name: 'kics-iac-sast-0', pipeline: pipeline, project: project) }
        let_it_be(:iac_build_1) { create(:ci_build, name: 'kics-iac-sast-1', pipeline: pipeline, project: project) }

        before do
          create(:ci_job_artifact, :sast, job: iac_build_0, project: project)
        end

        it 'returns true when any IaC job has artifacts' do
          expect(described_class.map_field(project, 'scanner_iac_running')).to be true
        end
      end
    end

    describe '#project_repo_exists?' do
      it 'delegates to project#repository_exists?' do
        expect(project.repository).to receive(:exists?)

        described_class.map_field(project, 'project_repo_exists')
      end
    end

    describe '#issue_tracking_enabled' do
      it 'returns true if all of the merged MRs have related issues' do
        allow(Project).to receive(:owners).and_return([create(:user)])
        issue = create(:issue, project: project)
        create(:merge_request, description: "Fix #{issue.to_reference}")

        expect(described_class.map_field(project, 'issue_tracking_enabled')).to be true
      end

      it 'returns false if any of the merged MRs do not have a related issue' do
        allow(Project).to receive(:owners).and_return([create(:user)])
        create(:merge_request, :merged, source_project: project, target_project: project)

        expect(described_class.map_field(project, 'issue_tracking_enabled')).to be false
      end
    end

    describe '#code_changes_requires_code_owners?' do
      it 'delegates to ProtectedBranch.branch_requires_code_owner_approval? with default branch' do
        expect(ProtectedBranch).to receive(:branch_requires_code_owner_approval?)
                                     .with(project, project.default_branch)

        described_class.map_field(project, 'code_changes_requires_code_owners')
      end

      context 'when project has no default branch' do
        before do
          allow(project).to receive(:default_branch).and_return(nil)
        end

        it 'returns false' do
          expect(described_class.map_field(project, 'code_changes_requires_code_owners')).to be false
        end
      end

      context 'when default branch requires code owner approval' do
        before do
          stub_licensed_features(code_owner_approval_required: true)
          create(:protected_branch, project: project, name: project.default_branch, code_owner_approval_required: true)
        end

        it 'returns true' do
          expect(described_class.map_field(project.reload, 'code_changes_requires_code_owners')).to be true
        end
      end

      context 'when default branch does not require code owner approval' do
        before do
          stub_licensed_features(code_owner_approval_required: true)
          create(:protected_branch, project: project, name: project.default_branch, code_owner_approval_required: false)
        end

        it 'returns false' do
          expect(described_class.map_field(project.reload, 'code_changes_requires_code_owners')).to be false
        end
      end
    end

    describe '#stale_branch_cleanup_enabled?' do
      let(:project) { instance_double(Project, repository: repository) }
      let(:repository) { instance_double(Repository) }
      let(:branches_finder) { instance_double(BranchesFinder) }

      before do
        allow(BranchesFinder).to receive(:new)
          .with(repository, { per_page: 1, sort: 'updated_asc' })
          .and_return(branches_finder)
        allow(branches_finder).to receive(:execute)
          .with(gitaly_pagination: true)
          .and_return([])
      end

      it 'delegates to BranchesFinder' do
        described_class.map_field(project, 'stale_branch_cleanup_enabled')

        expect(BranchesFinder).to have_received(:new)
          .with(repository, { per_page: 1, sort: 'updated_asc' })
        expect(branches_finder).to have_received(:execute)
          .with(gitaly_pagination: true)
      end
    end

    describe '#protected_branches_set?' do
      it 'returns true if there are any protected branches' do
        create(:protected_branch, project: project)
        expect(described_class.map_field(project, 'protected_branches_set')).to be true
      end

      it 'returns false if there are no protected branches' do
        expect(described_class.map_field(project, 'protected_branches_set')).to be false
      end
    end

    describe '#code_owner_approval_required?' do
      let(:loader) { instance_double(Gitlab::CodeOwners::Loader) }

      before do
        allow(Gitlab::CodeOwners::Loader).to receive(:new)
          .with(project, project.default_branch)
          .and_return(loader)
      end

      it 'returns true if the default branch has a CODEOWNER file' do
        expect(loader).to receive(:has_code_owners_file?)
          .and_return(true)

        expect(described_class.map_field(project, 'code_owner_approval_required')).to be true
      end

      it 'returns false if the default branch does not have a CODEOWNER file' do
        expect(loader).to receive(:has_code_owners_file?)
          .and_return(false)

        expect(described_class.map_field(project, 'code_owner_approval_required')).to be false
      end
    end

    describe '#reset_approvals_on_push?' do
      it 'delegates to project#reset_approvals_on_push' do
        expect(project).to receive(:reset_approvals_on_push)

        described_class.map_field(project, 'reset_approvals_on_push')
      end
    end

    describe '#status_checks_required?' do
      it 'delegates to project#only_allow_merge_if_all_status_checks_passed' do
        expect(project).to receive(:only_allow_merge_if_all_status_checks_passed)

        described_class.map_field(project, 'status_checks_required')
      end
    end

    describe '#require_branch_up_to_date?' do
      it 'returns true if the project merge_method is rebase_merge or ff' do
        expect(project).to receive(:merge_method).and_return(:rebase_merge)
        expect(described_class.map_field(project, 'require_branch_up_to_date')).to be true

        expect(project).to receive(:merge_method).and_return(:ff)
        expect(described_class.map_field(project, 'require_branch_up_to_date')).to be true
      end

      it 'returns false if the project merge_method is not rebase_merge or ff' do
        expect(project).to receive(:merge_method).and_return(:merge)
        expect(described_class.map_field(project, 'require_branch_up_to_date')).to be false
      end
    end

    describe '#resolve_discussions_required?' do
      it 'delegates to project#only_allow_merge_if_all_discussions_are_resolved' do
        expect(project).to receive(:only_allow_merge_if_all_discussions_are_resolved)

        described_class.map_field(project, 'resolve_discussions_required')
      end
    end

    describe '#require_signed_commits?' do
      it 'returns false if the project does not have push rules' do
        expect(described_class.map_field(project, 'require_signed_commits')).to be false
      end

      it 'returns false if the project push rules do not require signed commits' do
        create(:push_rule, project: project)
        expect(described_class.map_field(project, 'require_signed_commits')).to be false
      end

      it 'returns true if the project push rules require signed commits' do
        create(:push_rule, project: project, reject_unsigned_commits: true)
        expect(described_class.map_field(project, 'require_signed_commits')).to be true
      end
    end

    describe '#require_linear_history?' do
      it 'returns false if the project merge_method is rebase_merge or merge' do
        expect(project).to receive(:merge_method).and_return(:rebase_merge)
        expect(described_class.map_field(project, 'require_linear_history')).to be false

        expect(project).to receive(:merge_method).and_return(:merge)
        expect(described_class.map_field(project, 'require_linear_history')).to be false
      end

      it 'returns true if the project merge_method is not rebase_merge or ff' do
        expect(project).to receive(:merge_method).and_return(:ff)
        expect(described_class.map_field(project, 'require_linear_history')).to be true
      end
    end

    describe '#restrict_push_merge_access?' do
      it 'returns true if all protected branches disallow force_push' do
        create(:protected_branch, project: project, allow_force_push: false)

        expect(described_class.map_field(project.reload, 'restrict_push_merge_access')).to be true
      end

      it 'returns false if any protected branbches allow force_push' do
        create(:protected_branch, project: project, allow_force_push: true)

        expect(described_class.map_field(project.reload, 'restrict_push_merge_access')).to be false
      end
    end

    describe '#force_push_disabled?' do
      it 'delegates to ProtectedBranch.allow_force_push?' do
        expect(ProtectedBranch).to receive(:allow_force_push?)
                                     .with(project, nil)

        described_class.map_field(project, 'force_push_disabled')
      end
    end

    describe 'terraform_enabled' do
      context 'when terraform states exist' do
        it 'returns true' do
          create(:terraform_state, project: project)

          expect(described_class.map_field(project, 'terraform_enabled')).to be true
        end
      end

      context 'when terraform states do not exist' do
        it 'returns false' do
          expect(described_class.map_field(project, 'terraform_enabled')).to be false
        end
      end
    end

    describe '#branch_deletion_disabled?' do
      it 'returns true if any protected branches exist' do
        create(:protected_branch, project: project)

        expect(described_class.map_field(project.reload, 'branch_deletion_disabled')).to be true
      end

      it 'returns false if no protected branches exist' do
        expect(described_class.map_field(project.reload, 'branch_deletion_disabled')).to be false
      end
    end

    describe '#has_forks?' do
      it 'returns true if the project has forks' do
        fork_project(project)

        expect(described_class.map_field(project, 'has_forks')).to be true
      end

      it 'returns false if the project has no forks' do
        expect(described_class.map_field(project, 'has_forks')).to be false
      end
    end

    describe '#review_and_archive_stale_repos?' do
      it 'returns true if the project is archived' do
        project = build(:project, :archived)
        expect(described_class.map_field(project, 'review_and_archive_stale_repos')).to be true
      end

      it 'returns true if the project has been active in 6 months' do
        project = build(:project, last_activity_at: 5.months.ago)
        expect(described_class.map_field(project, 'review_and_archive_stale_repos')).to be true
      end

      it 'returns false if the project has been inactive for 6 months and is not archived' do
        project = build(:project, last_activity_at: 7.months.ago)
        expect(described_class.map_field(project, 'review_and_archive_stale_repos')).to be false
      end

      it 'returns true when an ancestor project is archived, but the project itself is not' do
        project = build(:project, last_activity_at: 5.months.ago)
        allow(project).to receive(:self_or_ancestors_archived?).and_return(true)
        expect(described_class.map_field(project, 'review_and_archive_stale_repos')).to be true
      end

      it 'returns true when neither the project nor its ancestors are archived and the project is not stale' do
        project = build(:project, last_activity_at: 5.months.ago)
        allow(project).to receive(:self_or_ancestors_archived?).and_return(false)
        expect(described_class.map_field(project, 'review_and_archive_stale_repos')).to be true
      end
    end

    describe '#review_and_remove_inactive_users?' do
      let(:project1) { build(:project) }

      before do
        project1.owner.update!(last_activity_on: Time.zone.now)
      end

      it 'returns true if all of the project members have been active in the last 90 days' do
        expect(described_class.map_field(project1, 'review_and_remove_inactive_users')).to be true
      end

      it 'returns false if any of the project members have nil activity values' do
        user = create(:user, last_activity_on: nil)
        project1.team.add_developer(user)

        expect(described_class.map_field(project1, 'review_and_remove_inactive_users')).to be false
      end

      it 'returns false if any of the project members have been inactive for 90 days' do
        user1 = create(:user, last_activity_on: 91.days.ago)
        project1.team.add_developer(user1)

        expect(described_class.map_field(project1, 'review_and_remove_inactive_users')).to be false
      end
    end

    describe '#more_members_than_admins?' do
      let(:project1) { build(:project) }

      it 'returns true if the project has only one admin (owner/maintainer)' do
        project1.team.add_maintainer(create(:user))

        expect(described_class.map_field(project1, 'more_members_than_admins')).to be true
      end

      it 'returns true if the project has more users of developers or below role than admins (owners/maintainers)' do
        project1.team.add_maintainer(create(:user))
        project1.team.add_developer(create(:user))
        project1.team.add_reporter(create(:user))

        expect(described_class.map_field(project1, 'more_members_than_admins')).to be true
      end

      it 'returns false if the project has only admins (owners/maintainers)' do
        project1.team.add_owner(create(:user))
        project1.team.add_maintainer(create(:user))

        expect(described_class.map_field(project1, 'more_members_than_admins')).to be false
      end
    end

    describe '#require_mfa_for_contributors?' do
      it 'delegates to namespace#require_two_factor_authentication' do
        expect(project.namespace).to receive(:require_two_factor_authentication)

        described_class.map_field(project, 'require_mfa_for_contributors')
      end
    end

    describe '#require_mfa_at_org_level?' do
      it 'returns true if the namespace requires MFA' do
        expect(project.namespace).to receive(:require_two_factor_authentication).and_return(true)
        expect(described_class.map_field(project, 'require_mfa_at_org_level')).to be true
      end

      it 'returns true if the namespace has a two factor grace period' do
        expect(project.namespace).to receive(:require_two_factor_authentication).and_return(false)
        expect(project.namespace).to receive(:two_factor_grace_period).and_return(1)
        expect(described_class.map_field(project, 'require_mfa_at_org_level')).to be true
      end

      it 'returns false if the namespace does not require MFA or have a two factor grace period' do
        expect(project.namespace).to receive(:require_two_factor_authentication).and_return(false)
        expect(project.namespace).to receive(:two_factor_grace_period).and_return(0)
        expect(described_class.map_field(project, 'require_mfa_at_org_level')).to be false
      end
    end

    describe '#ensure_2_admins_per_repo?' do
      it 'returns true if the project has at least 2 owners' do
        project1 = build(:project)
        project1.team.add_owner(create(:user))

        expect(described_class.map_field(project1, 'ensure_2_admins_per_repo')).to be true
      end

      it 'returns false if the project has less than 2 owners' do
        project1 = build(:project)

        expect(described_class.map_field(project1, 'ensure_2_admins_per_repo')).to be false
      end
    end

    describe '#strict_permissions_for_repo?' do
      let(:project1) { build(:project) }

      it 'returns true if the project has only one member' do
        project1.team.add_maintainer(create(:user))
        expect(described_class.map_field(project1, 'strict_permissions_for_repo')).to be true
      end

      it 'returns true if the project has more owners/maintainers than admins' do
        project1.team.add_maintainer(create(:user))
        project1.team.add_developer(create(:user))
        project1.team.add_developer(create(:user))

        expect(described_class.map_field(project1, 'strict_permissions_for_repo')).to be true
      end

      it 'returns false if the project has only owners/maintainers' do
        project1.team.add_owner(create(:user))
        project1.team.add_maintainer(create(:user))

        expect(described_class.map_field(project1, 'strict_permissions_for_repo')).to be false
      end
    end

    describe '#secure_webhooks?' do
      it 'returns true if all webhooks use https' do
        create(:project_hook, project: project, url: 'https://example.com')
        create(:project_hook, project: project, url: 'https://example2.com')

        expect(described_class.map_field(project.reload, 'secure_webhooks')).to be true
      end

      it 'returns false if any webhooks use http' do
        create(:project_hook, project: project, url: 'https://example.com')
        create(:project_hook, project: project, url: 'http://example2.com')

        expect(described_class.map_field(project.reload, 'secure_webhooks')).to be false
      end
    end

    describe '#restricted_build_access?' do
      let(:project1) { build(:project) }

      it 'returns true if there are fewer than 3 members with access levels of reporter and above' do
        expect(described_class.map_field(project1, 'restricted_build_access')).to be true
      end

      context 'with 3 members with access levels of reporter and above' do
        before do
          project1.team.add_developer(create(:user))
          project1.team.add_developer(create(:user))
        end

        it 'returns true if the percentage of members with access levels of reporter and above is less than 40%' do
          project1.team.add_planner(create(:user))
          project1.team.add_planner(create(:user))
          project1.team.add_planner(create(:user))
          project1.team.add_planner(create(:user))
          project1.team.add_planner(create(:user))
          project1.team.add_planner(create(:user))

          expect(described_class.map_field(project1, 'restricted_build_access')).to be true
        end

        it 'returns false if the percentage of members with access levels of reporter and above is 40% or more' do
          project1.team.add_planner(create(:user))
          project1.team.add_planner(create(:user))

          expect(described_class.map_field(project1, 'restricted_build_access')).to be false
        end
      end
    end

    describe 'gitlab_license_level_ultimate' do
      let(:license) { instance_double(License) }
      let(:ultimate_features) { [:feature1, :feature2] }

      before do
        allow(License).to receive(:current).and_return(license)
        stub_const('GitlabSubscriptions::Features::ULTIMATE_FEATURES', ultimate_features)
      end

      it 'returns true when license is ultimate and project has ultimate features' do
        allow(license).to receive(:ultimate?).and_return(true)
        allow(project).to receive(:licensed_features).and_return([:feature1])

        expect(described_class.map_field(project, 'gitlab_license_level_ultimate')).to be true
      end

      it 'returns false when license is ultimate but project has no ultimate features' do
        allow(license).to receive(:ultimate?).and_return(true)
        allow(project).to receive(:licensed_features).and_return([:other_feature])

        expect(described_class.map_field(project, 'gitlab_license_level_ultimate')).to be false
      end

      it 'returns false when license is not ultimate' do
        allow(license).to receive(:ultimate?).and_return(false)
        allow(project).to receive(:licensed_features).and_return([:feature1])

        expect(described_class.map_field(project, 'gitlab_license_level_ultimate')).to be false
      end
    end

    describe 'status_page_configured' do
      it 'returns true when status_page feature is available' do
        allow(project).to receive(:feature_available?).with(:status_page).and_return(true)

        expect(described_class.map_field(project, 'status_page_configured')).to be true
      end

      it 'returns true when licensed_feature_available returns true for status_page' do
        allow(project).to receive(:feature_available?).with(:status_page).and_return(false)
        allow(project).to receive(:licensed_feature_available?).with(:status_page).and_return(true)

        expect(described_class.map_field(project, 'status_page_configured')).to be true
      end

      it 'returns false when status_page is not available' do
        allow(project).to receive(:feature_available?).with(:status_page).and_return(false)
        allow(project).to receive(:licensed_feature_available?).with(:status_page).and_return(false)

        expect(described_class.map_field(project, 'status_page_configured')).to be false
      end
    end

    describe 'has_valid_ci_config' do
      before do
        allow(project).to receive_messages(has_ci?: true, builds_enabled?: true)
      end

      it 'returns true when project has valid CI config' do
        yml_dump = '{ image: "ruby:3.0" }'
        config = instance_double(Gitlab::Ci::Config, valid?: true)
        sha = 'abc123'

        allow(project).to receive(:ci_config_for).with(project.default_branch).and_return(yml_dump)
        allow(project.repository).to receive(:root_ref_sha).and_return(sha)
        allow(Gitlab::Ci::Config).to receive(:new)
          .with(yml_dump, project: project, user: project.first_owner, sha: sha, ref: project.default_branch)
          .and_return(config)

        expect(described_class.map_field(project, 'has_valid_ci_config')).to be true
      end

      it 'returns false when project has invalid CI config' do
        yml_dump = '{ invalid: config }'
        config = instance_double(Gitlab::Ci::Config, valid?: false)
        sha = 'abc123'

        allow(project).to receive(:ci_config_for).with(project.default_branch).and_return(yml_dump)
        allow(project.repository).to receive(:root_ref_sha).and_return(sha)
        allow(Gitlab::Ci::Config).to receive(:new)
          .with(yml_dump, project: project, user: project.first_owner, sha: sha, ref: project.default_branch)
          .and_return(config)

        expect(described_class.map_field(project, 'has_valid_ci_config')).to be false
      end

      it 'evaluates the config as the project owner so private includes can be resolved' do
        yml_dump = '{ include: [{ project: "private/project", file: "/job.yml" }] }'
        sha = 'abc123'

        allow(project).to receive(:ci_config_for).with(project.default_branch).and_return(yml_dump)
        allow(project.repository).to receive(:root_ref_sha).and_return(sha)

        expect(Gitlab::Ci::Config).to receive(:new)
          .with(yml_dump, hash_including(user: project.first_owner))
          .and_return(instance_double(Gitlab::Ci::Config, valid?: true))

        described_class.map_field(project, 'has_valid_ci_config')
      end

      it 'returns false when project raises ConfigError' do
        sha = 'abc123'

        allow(project).to receive(:ci_config_for).with(project.default_branch).and_return('invalid')
        allow(project.repository).to receive(:root_ref_sha).and_return(sha)
        allow(Gitlab::Ci::Config).to receive(:new).and_raise(Gitlab::Ci::Config::ConfigError)

        expect(described_class.map_field(project, 'has_valid_ci_config')).to be false
      end

      it 'returns false when project has no CI' do
        allow(project).to receive(:has_ci?).and_return(false)

        expect(described_class.map_field(project, 'has_valid_ci_config')).to be false
      end

      it 'returns false when builds are not enabled' do
        allow(project).to receive(:builds_enabled?).and_return(false)

        expect(described_class.map_field(project, 'has_valid_ci_config')).to be false
      end

      it 'returns true when project has valid remote CI config' do
        config = instance_double(Gitlab::Ci::Config, valid?: true)
        sha = 'abc123'

        allow(project).to receive(:ci_config_for).with(project.default_branch).and_return(nil)
        allow(project.repository).to receive(:root_ref_sha).and_return(sha)
        allow(Gitlab::Ci::Config).to receive(:new)
          .with(nil, project: project, user: project.first_owner, sha: sha, ref: project.default_branch)
          .and_return(config)

        expect(described_class.map_field(project, 'has_valid_ci_config')).to be true
      end

      it 'returns false when remote CI config fetch times out' do
        sha = 'abc123'

        allow(project).to receive(:ci_config_for).with(project.default_branch).and_return(nil)
        allow(project.repository).to receive(:root_ref_sha).and_return(sha)
        allow(Gitlab::Ci::Config).to receive(:new).and_raise(Gitlab::Ci::Config::External::Context::TimeoutError)

        expect(described_class.map_field(project, 'has_valid_ci_config')).to be false
      end

      it 'returns false when root_ref_sha is nil' do
        allow(project).to receive(:ci_config_for).with(project.default_branch).and_return('some config')
        allow(project.repository).to receive(:root_ref_sha).and_return(nil)

        expect(described_class.map_field(project, 'has_valid_ci_config')).to be false
      end
    end

    describe 'error_tracking_enabled' do
      context 'with error tracking enabled' do
        let_it_be(:project_with_error_tracking) { create(:project) }

        before do
          create(:project_error_tracking_setting, project: project_with_error_tracking)
        end

        it 'returns true' do
          expect(described_class.map_field(project_with_error_tracking, 'error_tracking_enabled')).to be true
        end
      end

      context 'with error tracking disabled' do
        let_it_be(:project_with_disabled_error_tracking) { create(:project) }

        before do
          create(:project_error_tracking_setting, :disabled, project: project_with_disabled_error_tracking)
        end

        it 'returns false' do
          expect(described_class.map_field(project_with_disabled_error_tracking, 'error_tracking_enabled')).to be false
        end
      end

      context 'with no error tracking setting' do
        it 'returns false' do
          expect(described_class.map_field(project, 'error_tracking_enabled')).to be false
        end
      end
    end

    describe 'default_branch_users_can_push' do
      let_it_be(:project_with_repo) { create(:project, :small_repo) }
      let(:protected_branch) { instance_double(ProtectedBranch) }
      let(:push_access_level) { instance_double(ProtectedBranch::PushAccessLevel) }

      before do
        allow(ProtectedBranch).to receive(:protected?).with(project_with_repo,
          project_with_repo.default_branch).and_return(true)
        allow(project_with_repo).to receive(:empty_repo?).and_return(false)
        allow(project_with_repo.protected_branches).to receive(:find_by)
          .with(name: project_with_repo.default_branch)
          .and_return(protected_branch)
        allow(protected_branch).to receive(:push_access_levels).and_return([push_access_level])
        allow(push_access_level).to receive(:respond_to?).with(:role?).and_return(true)
        allow(push_access_level).to receive(:role?).and_return(true)
      end

      it 'returns true for maintainer when access level is sufficient' do
        allow(push_access_level).to receive(:access_level).and_return(Gitlab::Access::MAINTAINER)

        expect(described_class.map_field(project_with_repo, 'default_branch_users_can_push')).to be true
      end

      it 'returns false for maintainer when access level is insufficient' do
        allow(push_access_level).to receive(:access_level).and_return(Gitlab::Access::DEVELOPER)

        expect(described_class.map_field(project_with_repo, 'default_branch_users_can_push')).to be false
      end

      it 'returns false for non-protected branch' do
        allow(ProtectedBranch).to receive(:protected?).with(project_with_repo,
          project_with_repo.default_branch).and_return(false)

        expect(described_class.map_field(project_with_repo, 'default_branch_users_can_push')).to be false
      end

      it 'returns false for empty repo' do
        allow(project_with_repo).to receive(:empty_repo?).and_return(true)

        expect(described_class.map_field(project_with_repo, 'default_branch_users_can_push')).to be false
      end

      it 'returns false when no protected branch found' do
        allow(project_with_repo.protected_branches)
          .to receive(:find_by)
          .with(name: project_with_repo.default_branch)
          .and_return(nil)

        expect(described_class.map_field(project_with_repo, 'default_branch_users_can_push')).to be false
      end

      it 'returns false when no push access levels' do
        allow(protected_branch).to receive(:push_access_levels).and_return([])

        expect(described_class.map_field(project_with_repo, 'default_branch_users_can_push')).to be false
      end
    end

    describe 'default_branch_protected_from_direct_push' do
      context 'with nil default branch' do
        let_it_be(:project_without_default_branch) { create(:project) }

        before do
          allow(project_without_default_branch).to receive(:default_branch).and_return(nil)
        end

        it 'returns false' do
          expect(described_class.map_field(project_without_default_branch,
            'default_branch_protected_from_direct_push')).to be false
        end
      end

      context 'with default branch not protected' do
        before do
          allow(ProtectedBranch).to receive(:protected?).with(project, project.default_branch).and_return(false)
        end

        it 'returns false' do
          expect(described_class.map_field(project, 'default_branch_protected_from_direct_push')).to be false
        end
      end

      context 'with empty repository' do
        let_it_be(:empty_project) { create(:project) }

        before do
          allow(empty_project).to receive(:empty_repo?).and_return(true)
          allow(ProtectedBranch).to receive(:protected?).with(empty_project,
            empty_project.default_branch).and_return(true)
        end

        it 'returns false' do
          expect(described_class.map_field(empty_project, 'default_branch_protected_from_direct_push')).to be false
        end
      end

      context 'with protected default branch' do
        let_it_be(:project_with_repo) { create(:project, :small_repo) }

        before do
          allow(ProtectedBranch).to receive(:protected?).with(project_with_repo,
            project_with_repo.default_branch).and_return(true)
          allow(project_with_repo).to receive(:empty_repo?).and_return(false)
        end

        it 'returns true when no roles can push' do
          allow(described_class).to receive(:default_branch_users_can_push?).with(project_with_repo,
            role: :developer).and_return(false)
          allow(described_class).to receive(:default_branch_users_can_push?).with(project_with_repo,
            role: :maintainer).and_return(false)
          allow(described_class).to receive(:default_branch_users_can_push?).with(project_with_repo,
            role: :owner).and_return(false)

          expect(described_class.map_field(project_with_repo, 'default_branch_protected_from_direct_push')).to be true
        end

        it 'returns false when developer can push' do
          allow(described_class).to receive(:default_branch_users_can_push?).with(project_with_repo,
            role: :developer).and_return(true)
          allow(described_class).to receive(:default_branch_users_can_push?).with(project_with_repo,
            role: :maintainer).and_return(false)
          allow(described_class).to receive(:default_branch_users_can_push?).with(project_with_repo,
            role: :owner).and_return(false)

          expect(described_class.map_field(project_with_repo, 'default_branch_protected_from_direct_push')).to be false
        end

        it 'returns false when maintainer can push' do
          allow(described_class).to receive(:default_branch_users_can_push?).with(project_with_repo,
            role: :developer).and_return(false)
          allow(described_class).to receive(:default_branch_users_can_push?).with(project_with_repo,
            role: :maintainer).and_return(true)
          allow(described_class).to receive(:default_branch_users_can_push?).with(project_with_repo,
            role: :owner).and_return(false)

          expect(described_class.map_field(project_with_repo, 'default_branch_protected_from_direct_push')).to be false
        end

        it 'returns false when owner can push' do
          allow(described_class).to receive(:default_branch_users_can_push?).with(project_with_repo,
            role: :developer).and_return(false)
          allow(described_class).to receive(:default_branch_users_can_push?).with(project_with_repo,
            role: :maintainer).and_return(false)
          allow(described_class).to receive(:default_branch_users_can_push?).with(project_with_repo,
            role: :owner).and_return(true)

          expect(described_class.map_field(project_with_repo, 'default_branch_protected_from_direct_push')).to be false
        end
      end

      describe 'push_protection_enabled' do
        before do
          project.create_security_setting unless project.security_setting
        end

        it 'returns the value of secret_push_protection_enabled' do
          expect(project.security_setting).to receive(:secret_push_protection_enabled).and_return(true)
          expect(described_class.map_field(project, 'push_protection_enabled')).to be true

          expect(project.security_setting).to receive(:secret_push_protection_enabled).and_return(false)
          expect(described_class.map_field(project, 'push_protection_enabled')).to be false
        end
      end

      describe 'project_visibility_not_internal' do
        it 'returns the opposite of project.internal?' do
          allow(project).to receive(:internal?).and_return(false)
          expect(described_class.map_field(project, 'project_visibility_not_internal')).to be true

          allow(project).to receive(:internal?).and_return(true)
          expect(described_class.map_field(project, 'project_visibility_not_internal')).to be false
        end
      end

      describe 'project_archived' do
        it 'returns the value of project.archived?' do
          allow(project).to receive(:self_or_ancestors_archived?).and_return(true)
          expect(described_class.map_field(project, 'project_archived')).to be true

          allow(project).to receive(:self_or_ancestors_archived?).and_return(false)
          expect(described_class.map_field(project, 'project_archived')).to be false
        end

        it 'returns true when an ancestor project is archived, but the project itself is not' do
          allow(project).to receive_messages(archived?: false, self_or_ancestors_archived?: true)
          expect(described_class.map_field(project, 'project_archived')).to be true
        end

        it 'returns false when neither the project nor its ancestors are archived' do
          allow(project).to receive_messages(archived?: false, self_or_ancestors_archived?: false)
          expect(described_class.map_field(project, 'project_archived')).to be false
        end
      end

      describe 'default_branch_users_can_merge' do
        it 'returns false when project has no default branch' do
          allow(project).to receive(:default_branch).and_return(nil)
          expect(described_class.map_field(project, 'default_branch_users_can_merge')).to be false
        end

        it 'returns false when default branch is not protected' do
          allow(project).to receive(:default_branch).and_return('main')
          allow(ProtectedBranch).to receive(:default_branch_for).with(project).and_return(nil)
          expect(described_class.map_field(project, 'default_branch_users_can_merge')).to be false
        end

        it 'returns true when developers can merge to the default branch' do
          protected_branch = instance_double(ProtectedBranch)
          merge_access_level = instance_double(ProtectedBranch::MergeAccessLevel)

          allow(project).to receive(:default_branch).and_return('main')
          allow(ProtectedBranch).to receive(:default_branch_for).with(project).and_return(protected_branch)
          allow(protected_branch).to receive(:merge_access_levels).and_return([merge_access_level])
          allow(merge_access_level).to receive_messages(role?: true, access_level: Gitlab::Access::DEVELOPER)

          expect(described_class.map_field(project, 'default_branch_users_can_merge')).to be true
        end

        it 'returns false when only maintainers can merge to the default branch' do
          protected_branch = instance_double(ProtectedBranch)
          merge_access_level = instance_double(ProtectedBranch::MergeAccessLevel)

          allow(project).to receive(:default_branch).and_return('main')
          allow(ProtectedBranch).to receive(:default_branch_for).with(project).and_return(protected_branch)
          allow(protected_branch).to receive(:merge_access_levels).and_return([merge_access_level])
          allow(merge_access_level).to receive_messages(role?: false, access_level: Gitlab::Access::MAINTAINER)

          expect(described_class.map_field(project, 'default_branch_users_can_merge')).to be false
        end
      end

      describe 'merge_request_commit_reset_approvals' do
        it 'returns the value of reset_approvals_on_push?' do
          allow(project).to receive(:reset_approvals_on_push?).and_return(true)
          expect(described_class.map_field(project, 'merge_request_commit_reset_approvals')).to be true

          allow(project).to receive(:reset_approvals_on_push?).and_return(false)
          expect(described_class.map_field(project, 'merge_request_commit_reset_approvals')).to be false
        end
      end

      describe 'project_visibility_not_public' do
        it 'returns the opposite of project.public?' do
          allow(project).to receive(:public?).and_return(false)
          expect(described_class.map_field(project, 'project_visibility_not_public')).to be true

          allow(project).to receive(:public?).and_return(true)
          expect(described_class.map_field(project, 'project_visibility_not_public')).to be false
        end
      end

      describe 'package_hunter_no_findings_untriaged' do
        let(:finder) { instance_double(Security::VulnerabilityReadsFinder) }

        before do
          allow(project).to receive(:licensed_feature_available?).with(:security_dashboard).and_return(true)
          allow(Security::VulnerabilityReadsFinder).to receive(:new)
            .with(project, { scanner: %w[packagehunter], state: %w[detected confirmed] })
            .and_return(finder)
        end

        it 'returns false when security dashboard is not available' do
          allow(project).to receive(:licensed_feature_available?).with(:security_dashboard).and_return(false)
          expect(described_class.map_field(project, 'package_hunter_no_findings_untriaged')).to be false
        end

        it 'returns false when there are no findings' do
          allow(finder).to receive(:execute).and_return([])
          expect(described_class.map_field(project, 'package_hunter_no_findings_untriaged')).to be false
        end

        it 'returns true when there are findings' do
          allow(finder).to receive(:execute).and_return([double])
          expect(described_class.map_field(project, 'package_hunter_no_findings_untriaged')).to be true
        end
      end

      describe 'project_pipelines_not_public' do
        it 'returns true when builds access level is less than ENABLED' do
          allow(project.project_feature).to receive(:access_level).with(:builds).and_return(ProjectFeature::PRIVATE)
          allow(ProjectFeature).to receive(:access_level_from_str).with('enabled').and_return(ProjectFeature::ENABLED)
          expect(described_class.map_field(project, 'project_pipelines_not_public')).to be true
        end

        it 'returns false when builds access level is ENABLED or above' do
          allow(project.project_feature).to receive(:access_level).with(:builds).and_return(ProjectFeature::ENABLED)
          allow(ProjectFeature).to receive(:access_level_from_str).with('enabled').and_return(ProjectFeature::ENABLED)
          expect(described_class.map_field(project, 'project_pipelines_not_public')).to be false
        end
      end

      describe 'vulnerabilities_slo_days_over_threshold' do
        it 'returns false when there are no vulnerabilities' do
          oldest_vulnerability = nil
          allow(project.vulnerabilities).to receive_message_chain(:with_states, :order_created_at_desc, :with_limit,
            :first)
            .and_return(oldest_vulnerability)
          expect(described_class.map_field(project, 'vulnerabilities_slo_days_over_threshold')).to be false
        end

        it 'returns true when there are vulnerabilities older than the threshold' do
          oldest_vulnerability = instance_double(Vulnerability)
          allow(oldest_vulnerability).to receive(:created_at).and_return(181.days.ago)
          allow(project.vulnerabilities).to receive_message_chain(:with_states, :order_created_at_desc, :with_limit,
            :first)
            .and_return(oldest_vulnerability)
          expect(described_class.map_field(project, 'vulnerabilities_slo_days_over_threshold')).to be true
        end

        it 'returns false when vulnerabilities are newer than the threshold' do
          oldest_vulnerability = instance_double(Vulnerability)
          allow(oldest_vulnerability).to receive(:created_at).and_return(179.days.ago)
          allow(project.vulnerabilities).to receive_message_chain(:with_states, :order_created_at_desc, :with_limit,
            :first)
            .and_return(oldest_vulnerability)
          expect(described_class.map_field(project, 'vulnerabilities_slo_days_over_threshold')).to be false
        end
      end

      describe 'merge_requests_approval_rules_prevent_editing' do
        it 'returns the value of disable_overriding_approvers_per_merge_request?' do
          allow(project).to receive(:disable_overriding_approvers_per_merge_request?).and_return(true)
          expect(described_class.map_field(project, 'merge_requests_approval_rules_prevent_editing')).to be true

          allow(project).to receive(:disable_overriding_approvers_per_merge_request?).and_return(false)
          expect(described_class.map_field(project, 'merge_requests_approval_rules_prevent_editing')).to be false
        end
      end

      describe 'project_user_defined_variables_restricted_to_maintainers' do
        it 'returns false when project has no ci_cd_settings' do
          allow(project).to receive(:ci_cd_settings).and_return(nil)
          expect(described_class.map_field(project,
            'project_user_defined_variables_restricted_to_maintainers')).to be false
        end

        it 'returns true when restrict_user_defined_variables? is true' do
          allow(project).to receive(:restrict_user_defined_variables?).and_return(true)

          expect(described_class.map_field(project,
            'project_user_defined_variables_restricted_to_maintainers')).to be true
        end

        it 'returns false when restrict_user_defined_variables? is false' do
          allow(project).to receive(:restrict_user_defined_variables?).and_return(false)

          expect(described_class.map_field(project,
            'project_user_defined_variables_restricted_to_maintainers')).to be false
        end

        context 'when integrated with actual restrict_user_defined_variables? behavior' do
          it 'returns false when restrict_user_defined_variables? returns false (role is developer)' do
            allow(project).to receive_messages(
              restrict_user_defined_variables?: false,
              ci_pipeline_variables_minimum_override_role: 'developer'
            )
            expect(described_class.map_field(project,
              'project_user_defined_variables_restricted_to_maintainers')).to be false
          end

          it 'returns true when restrict_user_defined_variables? returns true (role is maintainer)' do
            allow(project).to receive_messages(
              restrict_user_defined_variables?: true,
              ci_pipeline_variables_minimum_override_role: 'maintainer'
            )
            expect(described_class.map_field(project,
              'project_user_defined_variables_restricted_to_maintainers')).to be true
          end

          it 'returns true when restrict_user_defined_variables? returns true (role is owner)' do
            allow(project).to receive_messages(
              restrict_user_defined_variables?: true,
              ci_pipeline_variables_minimum_override_role: 'owner'
            )
            expect(described_class.map_field(project,
              'project_user_defined_variables_restricted_to_maintainers')).to be true
          end

          it 'returns true when restrict_user_defined_variables? returns true (role is no_one_allowed)' do
            allow(project).to receive_messages(
              restrict_user_defined_variables?: true,
              ci_pipeline_variables_minimum_override_role: 'no_one_allowed'
            )
            expect(described_class.map_field(project,
              'project_user_defined_variables_restricted_to_maintainers')).to be true
          end
        end
      end

      describe 'merge_requests_require_code_owner_approval' do
        it 'returns the value of merge_requests_require_code_owner_approval?' do
          allow(project).to receive(:merge_requests_require_code_owner_approval?).and_return(true)
          expect(described_class.map_field(project, 'merge_requests_require_code_owner_approval')).to be true

          allow(project).to receive(:merge_requests_require_code_owner_approval?).and_return(false)
          expect(described_class.map_field(project, 'merge_requests_require_code_owner_approval')).to be false
        end
      end

      describe 'cicd_job_token_scope_enabled' do
        it 'returns the value of ci_inbound_job_token_scope_enabled?' do
          allow(project).to receive(:ci_inbound_job_token_scope_enabled?).and_return(true)
          expect(described_class.map_field(project, 'cicd_job_token_scope_enabled')).to be true

          allow(project).to receive(:ci_inbound_job_token_scope_enabled?).and_return(false)
          expect(described_class.map_field(project, 'cicd_job_token_scope_enabled')).to be false
        end
      end

      describe 'project_marked_for_deletion' do
        it 'returns true when project is marked for deletion' do
          allow(project).to receive_messages(
            self_deletion_scheduled?: true
          )
          expect(described_class.map_field(project, 'project_marked_for_deletion')).to be true
        end

        it 'returns false when project is not marked for deletion' do
          allow(project).to receive_messages(
            self_deletion_scheduled?: false
          )
          expect(described_class.map_field(project, 'project_marked_for_deletion')).to be false
        end
      end
    end
  end
end
