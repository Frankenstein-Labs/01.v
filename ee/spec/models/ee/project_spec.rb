# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Project, feature_category: :groups_and_projects do
  include AdminModeHelper
  include ProjectForksHelper
  include ::EE::GeoHelpers
  include ::ProjectHelpers
  using RSpec::Parameterized::TableSyntax

  let(:project) { create(:project) }

  describe 'associations' do
    it { is_expected.to delegate_method(:shared_runners_seconds).to(:statistics) }

    it { is_expected.to delegate_method(:ci_minutes_usage).to(:shared_runners_limit_namespace) }
    it { is_expected.to delegate_method(:shared_runners_minutes_limit_enabled?).to(:shared_runners_limit_namespace) }

    it { is_expected.to delegate_method(:prevent_merge_without_jira_issue).to(:project_setting) }
    it { is_expected.to delegate_method(:prevent_merge_without_jira_issue=).to(:project_setting).with_arguments(true) }
    it { is_expected.to delegate_method(:only_allow_merge_if_all_status_checks_passed).to(:project_setting) }
    it { is_expected.to delegate_method(:security_policy_management_project).to(:security_orchestration_policy_configuration) }
    it { is_expected.to delegate_method(:auto_duo_code_review_enabled).to(:project_setting) }
    it { is_expected.to delegate_method(:auto_duo_code_review_enabled=).to(:project_setting).with_arguments(true) }
    it { is_expected.to delegate_method(:duo_remote_flows_enabled).to(:project_setting) }
    it { is_expected.to delegate_method(:ai_audit_events_storage_enabled).to(:project_setting) }
    it { is_expected.to delegate_method(:duo_remote_flows_enabled=).to(:project_setting).with_arguments(true) }
    it { is_expected.to delegate_method(:duo_foundational_flows_enabled).to(:project_setting) }
    it { is_expected.to delegate_method(:duo_foundational_flows_enabled=).to(:project_setting).with_arguments(true) }

    it { is_expected.to have_one(:import_state).class_name('ProjectImportState') }
    it { is_expected.to have_one(:wiki_repository).class_name('Projects::WikiRepository').inverse_of(:project) }
    it { is_expected.to have_one(:push_rule).inverse_of(:project) }
    it { is_expected.to have_one(:status_page_setting).class_name('StatusPage::ProjectSetting') }
    it { is_expected.to have_many(:compliance_framework_settings).class_name('ComplianceManagement::ComplianceFramework::ProjectSettings') }
    it { is_expected.to have_many(:compliance_management_frameworks).class_name('ComplianceManagement::Framework') }
    it { is_expected.to have_many(:compliance_standards_adherence).class_name('Projects::ComplianceStandards::Adherence') }
    it { is_expected.to have_one(:security_setting).class_name('ProjectSecuritySetting') }
    it { is_expected.to have_one(:vulnerability_statistic).class_name('Vulnerabilities::Statistic') }
    it { is_expected.to have_one(:security_statistics).class_name('Security::ProjectStatistics') }
    it { is_expected.to have_one(:security_orchestration_policy_configuration).class_name('Security::OrchestrationPolicyConfiguration').inverse_of(:project) }
    it { is_expected.to have_one(:dependency_proxy_packages_setting).class_name('DependencyProxy::Packages::Setting').inverse_of(:project) }
    it { is_expected.to have_one(:project_push_rule).inverse_of(:project) }

    it { is_expected.to have_many(:path_locks) }
    it { is_expected.to have_many(:vulnerability_archives).class_name('Vulnerabilities::Archive') }
    it { is_expected.to have_many(:vulnerability_feedback) }
    it { is_expected.to have_many(:vulnerability_exports) }
    it { is_expected.to have_many(:vulnerability_scanners) }
    it { is_expected.to have_many(:dast_site_profiles) }
    it { is_expected.to have_many(:dast_site_tokens) }
    it { is_expected.to have_many(:dast_sites) }
    it { is_expected.to have_many(:audit_events).dependent(false) }
    it { is_expected.to have_many(:protected_environments) }
    it { is_expected.to have_many(:upstream_project_subscriptions) }
    it { is_expected.to have_many(:upstream_projects) }
    it { is_expected.to have_many(:downstream_project_subscriptions) }
    it { is_expected.to have_many(:vulnerability_historical_statistics).class_name('Vulnerabilities::HistoricalStatistic') }
    it { is_expected.to have_many(:vulnerability_remediations).class_name('Vulnerabilities::Remediation') }
    it { is_expected.to have_many(:vulnerability_reads).class_name('Vulnerabilities::Read') }
    it { is_expected.to have_many(:security_ascp_scans).class_name('Security::Ascp::Scan') }
    it { is_expected.to have_many(:merge_train_cars).class_name('MergeTrains::Car') }
    it { is_expected.to have_many(:xray_reports).class_name('Projects::XrayReport') }
    it { is_expected.to have_many(:observability_metrics).class_name('Observability::MetricsIssuesConnection') }
    it { is_expected.to have_many(:observability_traces).class_name('Observability::TracesIssuesConnection') }
    it { is_expected.to have_many(:security_policy_management_project_linked_configurations).class_name('Security::OrchestrationPolicyConfiguration') }
    it { is_expected.to have_many(:security_policy_project_linked_projects).through(:security_policy_management_project_linked_configurations) }
    it { is_expected.to have_many(:security_policy_project_linked_namespaces).through(:security_policy_management_project_linked_configurations) }
    it { is_expected.to have_many(:security_policy_project_linked_groups).through(:security_policy_management_project_linked_configurations) }
    it { is_expected.to have_many(:security_scan_profile_triggers).through(:security_scan_profiles) }

    it { is_expected.to have_many(:observability_logs).class_name('Observability::LogsIssuesConnection') }

    it { is_expected.to have_many(:security_policy_project_links) }
    it { is_expected.to have_many(:security_policies).through(:security_policy_project_links) }
    it { is_expected.to have_many(:approval_policy_rule_project_links) }
    it { is_expected.to have_many(:approval_policy_rules).through(:approval_policy_rule_project_links) }
    it { is_expected.to have_many(:security_pipeline_execution_config_links).class_name('Security::PipelineExecutionPolicyConfigLink') }

    it { is_expected.to have_one(:github_integration) }
    it { is_expected.to have_one(:amazon_q_integration) }
    it { is_expected.to have_many(:zoekt_repositories) }
    it { is_expected.to have_one(:google_cloud_platform_artifact_registry_integration) }
    it { is_expected.to have_one(:google_cloud_platform_workload_identity_federation_integration) }
    it { is_expected.to have_one(:git_guardian_integration) }
    it { is_expected.to have_many(:project_aliases) }
    it { is_expected.to have_many(:approval_rules) }

    it { is_expected.to have_many(:incident_management_oncall_schedules).class_name('IncidentManagement::OncallSchedule') }
    it { is_expected.to have_many(:incident_management_oncall_rotations).through(:incident_management_oncall_schedules).source(:rotations) }
    it { is_expected.to have_many(:incident_management_escalation_policies).class_name('IncidentManagement::EscalationPolicy') }

    it { is_expected.to have_many(:security_scans) }
    it { is_expected.to have_many(:security_trainings) }
    it { is_expected.to have_many(:vulnerability_hooks_integrations).class_name('Integration') }

    it { is_expected.to have_many(:dependency_list_exports).class_name('Dependencies::DependencyListExport') }

    it { is_expected.to have_many(:sbom_occurrences).class_name('Sbom::Occurrence') }

    it { is_expected.to have_one(:analytics_dashboards_pointer) }
    it { is_expected.to have_one(:analytics_dashboards_configuration_project) }
    it { is_expected.to have_many(:targeting_dashboards_pointers).class_name('Analytics::Dashboards::DashboardsPointer') }
    it { is_expected.to have_many(:targeting_dashboards_pointer_projects).through(:targeting_dashboards_pointers).source(:project) }

    it { is_expected.to have_many(:custom_software_licenses) }
    it { is_expected.to have_many(:approval_policies).through(:security_policy_project_links).source(:security_policy) }

    it { is_expected.to have_many(:security_exclusions).class_name('Security::ProjectSecurityExclusion') }
    it { is_expected.to have_many(:analyzer_statuses).class_name('Security::AnalyzerProjectStatus') }

    it { is_expected.to have_many(:project_control_compliance_statuses) }
    it { is_expected.to have_many(:project_requirement_compliance_statuses) }

    it { is_expected.to have_many(:instance_runner_monthly_usages).class_name('Ci::Minutes::InstanceRunnerMonthlyUsage') }
    it { is_expected.to have_many(:hosted_runner_monthly_usages).class_name('Ci::Minutes::GitlabHostedRunnerMonthlyUsage') }

    it { is_expected.to have_many(:workspaces).class_name('RemoteDevelopment::Workspace') }
    it { is_expected.to have_many(:workspace_agentk_states).class_name('RemoteDevelopment::WorkspaceAgentkState') }

    it { is_expected.to have_many(:configured_ai_catalog_items).class_name('Ai::Catalog::ItemConsumer') }
    it { is_expected.to have_many(:ai_flow_triggers).class_name('Ai::FlowTrigger') }
    it { is_expected.to have_many(:policy_dismissals).class_name('Security::PolicyDismissal') }
    it { is_expected.to have_many(:enabled_foundational_flow_records).class_name('Ai::Catalog::EnabledFoundationalFlow') }

    include_examples 'ci_cd_settings delegation' do
      let(:attributes_with_prefix) do
        {
          'allow_composite_identities_to_run_pipelines' => '',
          'group_runners_enabled' => '',
          'default_git_depth' => 'ci_',
          'forward_deployment_enabled' => 'ci_',
          'forward_deployment_rollback_allowed' => 'ci_',
          'keep_latest_artifact' => '',
          'pipeline_variables_minimum_override_role' => 'ci_',
          'runner_token_expiration_interval' => '',
          'separated_caches' => 'ci_',
          'allow_fork_pipelines_to_run_in_parent_project' => 'ci_',
          'cross_project_push_for_job_token_allowed' => 'ci_',
          'inbound_job_token_scope_enabled' => 'ci_',
          'push_repository_for_job_token_allowed' => 'ci_',
          'id_token_sub_claim_components' => 'ci_',
          'delete_pipelines_in_seconds' => 'ci_',
          'job_token_scope_enabled' => 'ci_outbound_',
          'display_pipeline_variables' => 'ci_',
          'skip_branch_pipelines_for_mrs' => 'ci_',
          'resource_group_default_process_mode' => '',
          # EE only
          'auto_rollback_enabled' => '',
          'merge_pipelines_enabled' => '',
          'merge_trains_enabled' => '',
          'merge_trains_skip_train_allowed' => '',
          'merge_train_enforcement' => '',
          'max_pipelines_per_merge_train' => ''
        }
      end

      let(:exclude_attributes) do
        %w[
          restrict_pipeline_cancellation_role
        ]
      end
    end

    # can't be tested above because it can be nil
    it { is_expected.to delegate_method(:restrict_pipeline_cancellation_role).to(:ci_cd_settings) }

    describe '#merge_pipelines_enabled?' do
      it_behaves_like 'a ci_cd_settings predicate method' do
        let(:delegated_method) { :merge_pipelines_enabled? }
      end
    end

    describe '#merge_pipelines_were_disabled?' do
      it_behaves_like 'a ci_cd_settings predicate method' do
        let(:delegated_method) { :merge_pipelines_were_disabled? }
      end
    end

    describe '#merge_trains_enabled?' do
      it_behaves_like 'a ci_cd_settings predicate method' do
        let(:delegated_method) { :merge_trains_enabled? }
      end
    end

    describe '#auto_rollback_enabled?' do
      it_behaves_like 'a ci_cd_settings predicate method' do
        let(:delegated_method) { :auto_rollback_enabled? }
      end
    end

    describe '#jira_vulnerabilities_integration_enabled?' do
      context 'when project lacks a jira_integration relation' do
        it 'returns false' do
          expect(project.jira_vulnerabilities_integration_enabled?).to be false
        end
      end

      context 'when project has a jira_integration relation' do
        before do
          create(:jira_integration, project: project)
        end

        it 'accesses the value from the jira_integration' do
          expect(project.jira_integration)
            .to receive(:jira_vulnerabilities_integration_enabled?)

          project.jira_vulnerabilities_integration_enabled?
        end
      end
    end

    describe '#configured_to_create_issues_from_vulnerabilities?' do
      context 'when project lacks a jira_integration relation' do
        it 'returns false' do
          expect(project.configured_to_create_issues_from_vulnerabilities?).to be false
        end
      end

      context 'when project has a jira_integration relation' do
        before do
          create(:jira_integration, project: project)
        end

        it 'accesses the value from the jira_integration' do
          expect(project.jira_integration)
            .to receive(:configured_to_create_issues_from_vulnerabilities?)

          project.configured_to_create_issues_from_vulnerabilities?
        end
      end
    end

    describe '#jira_issue_association_required_to_merge_enabled?' do
      before do
        stub_licensed_features(
          jira_issues_integration: jira_integration_licensed,
          jira_issue_association_enforcement: jira_enforcement_licensed
        )

        project.build_jira_integration(active: jira_integration_active)
      end

      where(
        jira_integration_licensed: [true, false],
        jira_integration_active: [true, false],
        jira_enforcement_licensed: [true, false]
      )

      with_them do
        it 'is enabled if all values are true' do
          expect(project.jira_issue_association_required_to_merge_enabled?).to be(
            jira_integration_licensed && jira_integration_active && jira_enforcement_licensed
          )
        end
      end
    end

    describe '#dependency_management_service_account' do
      let_it_be(:project) { create(:project) }
      let_it_be(:dep_mgmt_service_account) do
        create(:service_account,
          provisioned_by_project: project,
          name: DependencyManagement::ProvisionServiceAccountService::SERVICE_ACCOUNT_NAME
        )
      end

      let_it_be(:other_service_account) do
        create(:service_account,
          provisioned_by_project: project,
          name: 'Some Other Service Account'
        )
      end

      let_it_be(:other_project_service_account) do
        create(:service_account,
          provisioned_by_project: create(:project),
          name: DependencyManagement::ProvisionServiceAccountService::SERVICE_ACCOUNT_NAME
        )
      end

      it 'returns the dependency management service account for the project' do
        expect(project.dependency_management_service_account).to eq(dep_mgmt_service_account)
      end

      it 'does not return service accounts with a different name' do
        expect(project.dependency_management_service_account).not_to eq(other_service_account)
      end

      it 'does not return service accounts provisioned for other projects' do
        expect(project.dependency_management_service_account).not_to eq(other_project_service_account)
      end

      context 'when no dependency management service account exists' do
        let(:other_project) { build(:project) }

        it 'returns nil' do
          expect(other_project.dependency_management_service_account).to be_nil
        end
      end
    end

    context 'import_state dependant predicate method' do
      shared_examples 'returns expected values' do
        context 'when project lacks a import_state relation' do
          it 'returns false' do
            expect(project.send("mirror_#{method}")).to be_falsey
          end
        end

        context 'when project has a import_state relation' do
          before do
            create(:import_state, project: project)
          end

          it 'accesses the value from the import_state' do
            expect(project.import_state).to receive(method)

            project.send("mirror_#{method}")
          end
        end
      end

      describe '#mirror_last_update_succeeded?' do
        it_behaves_like 'returns expected values' do
          let(:method) { "last_update_succeeded?" }
        end
      end

      describe '#mirror_last_update_failed?' do
        it_behaves_like 'returns expected values' do
          let(:method) { "last_update_failed?" }
        end
      end

      describe '#mirror_ever_updated_successfully?' do
        it_behaves_like 'returns expected values' do
          let(:method) { "ever_updated_successfully?" }
        end
      end
    end

    describe 'approval_rules association' do
      let_it_be_with_reload(:rule) { create(:approval_project_rule) }

      let(:project) { rule.project }
      let(:branch) { 'stable' }

      describe '#applicable_to_branch' do
        subject { project.approval_rules.applicable_to_branch(branch) }

        context 'when there are no associated protected branches' do
          it { is_expected.to eq([rule]) }
        end

        context 'when there are associated protected branches' do
          before do
            rule.update!(protected_branches: protected_branches)
          end

          context 'and branch matches' do
            let(:protected_branches) { [create(:protected_branch, name: branch)] }

            it { is_expected.to eq([rule]) }

            context 'and multiple rules' do
              it 'avoids N+1 queries' do
                project.reload.approval_rules.applicable_to_branch(branch)

                control = ActiveRecord::QueryRecorder.new { project.reload.approval_rules.applicable_to_branch(branch) }

                create(:approval_project_rule, project: project, protected_branches: protected_branches)

                expect { project.reload.approval_rules.applicable_to_branch(branch) }.not_to exceed_query_limit(control)
              end
            end
          end

          context 'but branch does not match anything' do
            let(:protected_branches) { [create(:protected_branch, name: branch.reverse)] }

            it { is_expected.to be_empty }
          end
        end
      end

      describe '#inapplicable_to_branch' do
        subject { project.approval_rules.inapplicable_to_branch(branch) }

        context 'when there are no associated protected branches' do
          it { is_expected.to be_empty }
        end

        context 'when there are associated protected branches' do
          before do
            rule.update!(protected_branches: protected_branches)
          end

          context 'and branch does not match anything' do
            let(:protected_branches) { [create(:protected_branch, name: branch.reverse)] }

            it { is_expected.to eq([rule]) }

            context 'and multiple rules' do
              it 'avoids N+1 queries' do
                project.reload.approval_rules.inapplicable_to_branch(branch)

                control = ActiveRecord::QueryRecorder.new { project.reload.approval_rules.inapplicable_to_branch(branch) }

                create(:approval_project_rule, project: project, protected_branches: protected_branches)

                expect { project.reload.approval_rules.inapplicable_to_branch(branch) }.not_to exceed_query_limit(control)
              end
            end
          end

          context 'but branch matches' do
            let(:protected_branches) { [create(:protected_branch, name: branch)] }

            it { is_expected.to be_empty }
          end
        end
      end
    end

    context 'when deleting security policy project' do
      let_it_be(:project) { create(:project) }
      let_it_be(:policy_management_project) { create(:project) }
      let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, security_policy_management_project: policy_management_project, project: project) }

      it 'also deletes the associated security_orchestration_policy_configuration' do
        policy_management_project.delete

        expect(project.reload.security_orchestration_policy_configuration).to be_nil
      end
    end
  end

  context 'scopes' do
    describe '.requiring_code_owner_approval' do
      let!(:project) { create(:project) }
      let!(:expected_project) { protected_branch_needing_approval.project }
      let!(:protected_branch_needing_approval) { create(:protected_branch, code_owner_approval_required: true) }

      it 'only includes the right projects' do
        scoped_query_result = described_class.requiring_code_owner_approval

        expect(described_class.count).to eq(2)
        expect(scoped_query_result).to contain_exactly(expected_project)
      end
    end

    describe '.by_ids' do
      let_it_be(:project_1) { create(:project) }
      let_it_be(:project_2) { create(:project) }
      let_it_be(:project_3) { create(:project) }

      it 'returns projects with the specified ids' do
        expect(described_class.by_ids([project_1.id, project_2.id]))
          .to contain_exactly(project_1, project_2)
      end

      it 'returns empty when no matching ids exist' do
        expect(described_class.by_ids([non_existing_record_id]))
          .to be_empty
      end
    end

    describe '.with_namespaces' do
      let_it_be(:project) { create(:project) }

      it 'preloads the namespace association' do
        projects = described_class.with_namespaces.to_a
        project = projects.first

        expect(project.association(:namespace)).to be_loaded
      end

      it 'avoids N+1 queries' do
        control = ActiveRecord::QueryRecorder.new { described_class.with_namespaces.map(&:namespace) }

        create(:project)

        expect { described_class.with_namespaces.map(&:namespace) }.not_to exceed_query_limit(control)
      end
    end

    describe '.with_security_attributes' do
      let_it_be(:project) { create(:project) }

      it 'preloads the security attributes associations' do
        projects = described_class.with_security_attributes.to_a
        project = projects.first

        expect(project.association(:security_attributes)).to be_loaded
      end

      it 'avoids N+1 queries' do
        control = ActiveRecord::QueryRecorder.new { described_class.with_security_attributes.map(&:security_attributes) }

        create(:project)

        expect { described_class.with_security_attributes.map(&:security_attributes) }.not_to exceed_query_limit(control)
      end
    end

    describe '.with_wiki_enabled' do
      it 'returns a project' do
        project = create(:project_empty_repo, wiki_access_level: ProjectFeature::ENABLED)
        project1 = create(:project, wiki_access_level: ProjectFeature::DISABLED)

        expect(described_class.with_wiki_enabled).to include(project)
        expect(described_class.with_wiki_enabled).not_to include(project1)
      end
    end

    describe '.github_imported' do
      it 'returns the correct project' do
        project_imported_from_github = create(:project, :github_imported)
        project_not_imported_from_github = create(:project)

        expect(described_class.github_imported).to include(project_imported_from_github)
        expect(described_class.github_imported).not_to include(project_not_imported_from_github)
      end
    end

    describe '.with_protected_branches' do
      it 'returns the correct project' do
        project_with_protected_branches = create(:project, protected_branches: [create(:protected_branch)])
        project_without_protected_branches = create(:project)

        expect(described_class.with_protected_branches).to include(project_with_protected_branches)
        expect(described_class.with_protected_branches).not_to include(project_without_protected_branches)
      end
    end

    describe '.with_repositories_enabled' do
      it 'returns the correct project' do
        project_with_repositories_enabled = create(:project, :repository_enabled)
        project_with_repositories_disabled = create(:project, :repository_disabled)

        expect(described_class.with_repositories_enabled).to include(project_with_repositories_enabled)
        expect(described_class.with_repositories_enabled).not_to include(project_with_repositories_disabled)
      end
    end

    describe '.with_security_scans' do
      it 'returns the correct project' do
        project_without_security_scans = create(:project)
        project_with_security_scans = create(:project, :with_security_scans)

        expect(described_class.with_security_scans).to include(project_with_security_scans)
        expect(described_class.with_security_scans).not_to include(project_without_security_scans)
      end
    end

    describe '.with_github_integration_pipeline_events' do
      it 'returns the correct project' do
        project_with_github_integration_pipeline_events = create(:project, github_integration: create(:github_integration))
        project_without_github_integration_pipeline_events = create(:project)

        expect(described_class.with_github_integration_pipeline_events)
          .to include(project_with_github_integration_pipeline_events)
        expect(described_class.with_github_integration_pipeline_events)
          .not_to include(project_without_github_integration_pipeline_events)
      end
    end

    describe '.has_vulnerabilities' do
      let_it_be(:project_1) { create(:project) }
      let_it_be(:project_2) { create(:project) }
      let_it_be(:project_3) { create(:project) }

      before do
        project_1.project_setting.update!(has_vulnerabilities: true)
        project_2.project_setting.update!(has_vulnerabilities: false)
      end

      subject { described_class.has_vulnerabilities }

      it { is_expected.to contain_exactly(project_1) }
    end

    describe 'jira_subscription_exists?' do
      let_it_be(:project) { create(:project) }
      let_it_be(:jira_connect_subscription) { create(:jira_connect_subscription, namespace: project.namespace) }

      subject { project.jira_subscription_exists? }

      it { is_expected.to be(true) }

      it 'is false when the GitLab for Jira Cloud integration is blocked by settings' do
        allow(Integrations::JiraCloudApp).to receive(:blocked_by_settings?).and_return(true)

        is_expected.to be(false)
      end
    end

    describe '.order_by_excess_repo_storage_size_desc' do
      let_it_be(:project_1) { create(:project_statistics, lfs_objects_size: 10, repository_size: 10).project }
      let_it_be(:project_2) { create(:project_statistics, lfs_objects_size: 5, repository_size: 55).project }
      let_it_be(:project_3) { create(:project, repository_size_limit: 30, statistics: create(:project_statistics, lfs_objects_size: 8, repository_size: 32)) }

      let(:limit) { 20 }

      subject { described_class.order_by_excess_repo_storage_size_desc(limit) }

      it { is_expected.to eq([project_2, project_3, project_1]) }
    end

    describe '.with_coverage_feature_usage' do
      let_it_be(:project_1) { create(:project) }
      let_it_be(:project_2) { create(:project) }
      let_it_be(:project_3) { create(:project) }

      before_all do
        create(:project_ci_feature_usage, feature: :code_coverage, project: project_1, default_branch: true)
        create(:project_ci_feature_usage, feature: :code_coverage, project: project_1, default_branch: false)
        create(:project_ci_feature_usage, feature: :code_coverage, project: project_2, default_branch: false)
        create(:project_ci_feature_usage, feature: :security_report, project: project_3, default_branch: true)
      end

      context 'when default_branch is not specified' do
        subject { described_class.with_coverage_feature_usage }

        it { is_expected.to contain_exactly(project_1, project_2) }
      end

      context 'when default_branch is set to true' do
        subject { described_class.with_coverage_feature_usage(default_branch: true) }

        it { is_expected.to contain_exactly(project_1) }
      end

      context 'when default_branch is set to false' do
        subject { described_class.with_coverage_feature_usage(default_branch: false) }

        it { is_expected.to contain_exactly(project_1, project_2) }
      end
    end

    describe '.with_feature_available', :saas do
      let(:premium_feature) { GitlabSubscriptions::Features::PREMIUM_FEATURES.first }
      let_it_be(:user) { create(:user) }

      let_it_be(:ultimate_group) { create(:group_with_plan, :private, plan: :ultimate_plan) }
      let_it_be(:ultimate_subgroup) { create(:group, :private, parent: ultimate_group) }
      let_it_be(:another_ultimate_group) { create(:group_with_plan, :private, plan: :ultimate_plan) }
      let_it_be(:another_ultimate_subgroup) { create(:group, :private, parent: another_ultimate_group) }
      let_it_be(:premium_group) { create(:group_with_plan, :private, plan: :premium_plan) }
      let_it_be(:premium_subgroup) { create(:group, :private, parent: premium_group) }
      let_it_be(:no_plan_group) { create(:group_with_plan, :public, plan: nil) }
      let_it_be(:no_plan_subgroup) { create(:group, :public, parent: no_plan_group) }
      let_it_be(:ultimate_project) { create(:project, :private, :archived, creator: user, namespace: ultimate_group) }
      let_it_be(:premium_project) { create(:project, :private, :archived, creator: user, namespace: premium_group) }
      let_it_be(:no_plan_public_project) { create(:project, :public, :archived, creator: user, namespace: no_plan_group) }
      let_it_be(:ultimate_subgroup_project) { create(:project, :private, :archived, creator: user, namespace: ultimate_subgroup) }
      let_it_be(:another_ultimate_subgroup_project) { create(:project, :private, :archived, creator: user, namespace: another_ultimate_subgroup) }
      let_it_be(:premium_subgroup_project) { create(:project, :private, :archived, creator: user, namespace: premium_subgroup) }
      let_it_be(:no_plan_private_project) { create(:project, :private, :archived, creator: user, namespace: no_plan_group) }
      let_it_be(:no_plan_subgroup_private_project) { create(:project, :private, :archived, creator: user, namespace: no_plan_subgroup) }

      subject(:result) { described_class.with_feature_available(premium_feature) }

      it 'lists projects with the feature available' do
        is_expected.to contain_exactly(
          premium_project,
          premium_subgroup_project,
          ultimate_project,
          ultimate_subgroup_project,
          another_ultimate_subgroup_project,
          no_plan_public_project
        )
      end
    end

    describe '.with_project_setting' do
      it 'eager loads the project setting and avoids N+1 queries' do
        create(:project)
        project = described_class.with_project_setting.first
        recorder = ActiveRecord::QueryRecorder.new { project.project_setting }

        expect(recorder.count).to be_zero
        expect(project.association(:project_setting).loaded?).to be(true)
      end
    end

    context 'compliance framework scopes' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:project_with_framework_1) { create(:project, group: namespace) }
      let_it_be(:project_with_framework_2) { create(:project, group: namespace) }
      let_it_be(:project_without_framework) { create(:project, group: namespace) }
      let_it_be(:framework_1) { create(:compliance_framework, namespace: namespace, name: 'Test1') }
      let_it_be(:framework_2) { create(:compliance_framework, namespace: namespace, name: 'Test2') }
      let_it_be(:framework_3) { create(:compliance_framework, namespace: namespace, name: 'Test3') }
      let_it_be(:framework_settings_1) { create(:compliance_framework_project_setting, project: project_with_framework_1, compliance_management_framework: framework_1) }
      let_it_be(:framework_settings_2) { create(:compliance_framework_project_setting, project: project_with_framework_2, compliance_management_framework: framework_2) }

      describe '.compliance_framework_id_in' do
        context 'when correct framework id is passed' do
          subject { described_class.compliance_framework_id_in(framework_1.id) }

          it { is_expected.to contain_exactly(project_with_framework_1) }
        end

        context 'when correct framework ids are passed' do
          subject { described_class.compliance_framework_id_in([framework_1.id, framework_2.id]) }

          it { is_expected.to contain_exactly(project_with_framework_1, project_with_framework_2) }
        end

        context 'when one framework id is valid and another is non existing' do
          subject { described_class.compliance_framework_id_in([framework_1.id, non_existing_record_id]) }

          it { is_expected.to contain_exactly(project_with_framework_1) }
        end

        context 'when a project has more than one frameworks and both are used as filters' do
          let_it_be(:framework_settings_3) { create(:compliance_framework_project_setting, project: project_with_framework_1, compliance_management_framework: framework_2) }

          subject { described_class.compliance_framework_id_in([framework_1.id, framework_2.id]) }

          it { is_expected.to contain_exactly(project_with_framework_1, project_with_framework_2) }
        end

        context 'when same framework id is passed multiple times' do
          subject { described_class.compliance_framework_id_in([framework_1.id, framework_2.id, framework_1.id]) }

          it { is_expected.to contain_exactly(project_with_framework_1, project_with_framework_2) }
        end

        context 'when nil is passed as framework id' do
          subject { described_class.compliance_framework_id_in(nil) }

          it { is_expected.to be_empty }
        end

        context 'when the framework id passed is of non existing record' do
          subject { described_class.compliance_framework_id_in(non_existing_record_id) }

          it { is_expected.to be_empty }
        end
      end

      describe '.compliance_framework_id_not_in' do
        context 'when a valid framework id is passed' do
          subject { described_class.compliance_framework_id_not_in(framework_1.id) }

          it { is_expected.to contain_exactly(project_with_framework_2, project_without_framework) }
        end

        context 'when a valid framework ids are passed' do
          subject { described_class.compliance_framework_id_not_in([framework_1.id, framework_2.id]) }

          it { is_expected.to contain_exactly(project_without_framework) }
        end

        context 'when one framework id is valid and another is non existing' do
          subject { described_class.compliance_framework_id_not_in([framework_1.id, non_existing_record_id]) }

          it { is_expected.to contain_exactly(project_with_framework_2, project_without_framework) }
        end

        context 'when a project has multiple compliance frameworks' do
          let_it_be(:framework_settings_1) { create(:compliance_framework_project_setting, project: project_with_framework_1, compliance_management_framework: framework_2) }

          subject { described_class.compliance_framework_id_not_in([framework_2.id]) }

          it { is_expected.to contain_exactly(project_with_framework_1, project_without_framework) }
        end

        context 'when nil is passed as framework id' do
          subject { described_class.compliance_framework_id_not_in(nil) }

          it { is_expected.to contain_exactly(project_with_framework_1, project_with_framework_2, project_without_framework) }
        end

        context 'when the framework id passed is of non existing record' do
          subject { described_class.compliance_framework_id_not_in(non_existing_record_id) }

          it { is_expected.to contain_exactly(project_with_framework_1, project_with_framework_2, project_without_framework) }
        end
      end

      describe '.missing_compliance_framework' do
        subject { described_class.missing_compliance_framework }

        it { is_expected.to eq([project_without_framework]) }
      end

      describe '.any_compliance_framework' do
        # Second framework added to ensure each project is only returned once
        let_it_be(:additional_framework_for_project_2) do
          create :compliance_framework_project_setting,
            project: project_with_framework_2,
            compliance_management_framework: framework_3
        end

        subject { described_class.any_compliance_framework }

        it { is_expected.to match_array([project_with_framework_1, project_with_framework_2]) }
      end

      describe '.with_compliance_frameworks' do
        subject { described_class.all.with_compliance_frameworks([framework_1, framework_2]) }

        it { is_expected.to match_array([project_with_framework_1, project_with_framework_2]) }
      end

      describe '.not_with_compliance_frameworks' do
        subject { described_class.all.not_with_compliance_frameworks([framework_1]) }

        it { is_expected.to match_array([project_with_framework_2, project_without_framework]) }
      end
    end

    describe '.not_indexed_in_elasticsearch' do
      it "only matches indexed projects" do
        non_indexed_project = create(:project, :empty_repo)
        create(:project, :empty_repo).tap { |p| create(:index_status, project: p) }

        expect(described_class.not_indexed_in_elasticsearch).to match_array([non_indexed_project])
      end
    end

    describe '.preload_for_indexing' do
      let_it_be(:primary_project) { create(:project, :empty_repo, :mirror) }
      let_it_be(:forked_project) { create(:project, :fork_repository, forked_from_project: primary_project) }

      it 'preloads association data', :aggregate_failures do
        record = described_class.preload_for_indexing.first

        expect(record.association(:mirror_user)).to be_loaded
        expect(record.association(:project_feature)).to be_loaded
        expect(record.association(:route)).to be_loaded
        expect(record.association(:catalog_resource)).to be_loaded
        expect(record.association(:fork_network)).to be_loaded
        expect(record.association(:repository_languages)).to be_loaded
        expect(record.association(:group)).to be_loaded
        expect(record.association(:namespace)).to be_loaded
        expect(record.namespace.association(:owner)).to be_loaded
      end
    end

    describe '.without_zoekt_repositories_for_index' do
      let_it_be(:not_indexed_project) { create(:project) }
      let_it_be(:zoekt_index_1) { create(:zoekt_index) }
      let_it_be(:zoekt_index_2) { create(:zoekt_index) }
      let_it_be(:zoekt_repository_1) { create(:zoekt_repository, zoekt_index: zoekt_index_1) }
      let_it_be(:indexed_project_1) { zoekt_repository_1.project }

      # Project indexed in a different index but not in index_1
      let_it_be(:zoekt_repository_2) { create(:zoekt_repository, zoekt_index: zoekt_index_2) }
      let_it_be(:indexed_project_2) { zoekt_repository_2.project }

      # Project indexed in both indices
      let_it_be(:zoekt_repository_3) do
        create(:zoekt_repository, project: indexed_project_2, zoekt_index: zoekt_index_1)
      end

      context 'when checking for index_1' do
        it 'returns projects not indexed in the specified index' do
          expect(described_class.without_zoekt_repositories_for_index(zoekt_index_1.id))
            .to contain_exactly(not_indexed_project)
        end
      end

      context 'when checking for index_2' do
        it 'returns projects not indexed in the specified index' do
          expect(described_class.without_zoekt_repositories_for_index(zoekt_index_2.id))
            .to contain_exactly(not_indexed_project, indexed_project_1)
        end
      end

      context 'with multiple projects' do
        let_it_be(:additional_projects) { create_list(:project, 3) }

        it 'returns all projects not indexed in the specified index' do
          expect(described_class.without_zoekt_repositories_for_index(zoekt_index_1.id).count)
            .to eq(1 + additional_projects.size)
        end
      end
    end

    describe '.without_security_setting' do
      let_it_be(:project_with_security_setting) { create(:project) }
      let_it_be(:project_without_security_setting) { create(:project) }

      before do
        project_without_security_setting.security_setting.destroy!
      end

      it 'only returns projects without security_setting' do
        expect(described_class.without_security_setting).to match_array([project_without_security_setting])
      end
    end

    describe '.with_api_blob_entity_associations' do
      it 'preloads the expected associations' do
        expect(described_class.with_api_blob_entity_associations.preload_values).to contain_exactly(
          :project_feature,
          :route,
          :invited_groups,
          { namespace: [:route, :owner] }
        )
      end
    end
  end

  describe 'validations' do
    let(:project) { build(:project) }

    describe 'variables' do
      let(:first_variable) { build(:ci_variable, key: 'test_key', value: 'first', environment_scope: 'prod', project: project) }
      let(:second_variable) { build(:ci_variable, key: 'test_key', value: 'other', environment_scope: 'other', project: project) }

      before do
        project.variables << first_variable
        project.variables << second_variable
      end

      context 'with duplicate variables with same environment scope' do
        before do
          project.variables.last.environment_scope = project.variables.first.environment_scope
        end

        it { expect(project).not_to be_valid }
      end

      context 'with same variable keys and different environment scope' do
        it { expect(project).to be_valid }
      end

      it "ensures max_pages_size is an integer greater than 0 (or equal to 0 to indicate unlimited/maximum)" do
        is_expected.to validate_numericality_of(:max_pages_size).only_integer.is_greater_than_or_equal_to(0)
                         .is_less_than(::Gitlab::Pages::MAX_SIZE / 1.megabyte)
      end
    end

    context 'mirror' do
      subject { build(:project, mirror: true) }

      it { is_expected.to validate_presence_of(:import_url) }
      it { is_expected.to validate_presence_of(:mirror_user) }
    end

    context 'approvals_before_merge' do
      it { is_expected.to validate_numericality_of(:approvals_before_merge) }
      it { expect(build(:project, approvals_before_merge: nil)).to be_invalid }
    end

    it 'creates import state when mirror gets enabled' do
      project2 = create(:project)

      expect do
        project2.update!(mirror: true, import_url: generate(:url), mirror_user: project.creator)
      end.to change { ProjectImportState.where(project: project2).count }.from(0).to(1)
    end

    describe 'description templates' do
      before do
        allow(::Gitlab::CurrentSettings).to receive(:description_and_note_max_size).and_return(100)
      end

      shared_examples 'validates description template' do |template|
        it "allows an empty #{template}" do
          project[template] = ''

          expect(project).to be_valid
        end

        it "validates the length of #{template}" do
          project[template] = 'a' * 101

          expect(project).not_to be_valid
        end

        it "skips validation when #{template} is unchanged" do
          project[template] = 'a' * 101
          project.save!(validate: false)

          expect(project).to be_valid
        end
      end

      it_behaves_like 'validates description template', :issues_template
      it_behaves_like 'validates description template', :merge_requests_template
    end
  end

  describe 'update callbacks' do
    describe '.update_legacy_open_source_license_available' do
      where(:visibility_level, :new_visibility_level) do
        Gitlab::VisibilityLevel::PUBLIC | Gitlab::VisibilityLevel::INTERNAL
        Gitlab::VisibilityLevel::PUBLIC | Gitlab::VisibilityLevel::PRIVATE
        Gitlab::VisibilityLevel::INTERNAL | Gitlab::VisibilityLevel::PUBLIC
        Gitlab::VisibilityLevel::INTERNAL | Gitlab::VisibilityLevel::PRIVATE
        Gitlab::VisibilityLevel::PRIVATE | Gitlab::VisibilityLevel::PUBLIC
        Gitlab::VisibilityLevel::PRIVATE | Gitlab::VisibilityLevel::INTERNAL
      end

      with_them do
        let(:project) { create(:project, visibility_level: visibility_level) }

        before do
          project.project_setting.update!(legacy_open_source_license_available: true)
        end

        it 'sets `project_settings.legacy_open_source_license_available` to false' do
          project.update!(visibility_level: new_visibility_level)

          expect(project.project_setting.legacy_open_source_license_available).to be_falsey
        end
      end
    end

    describe '.elastic_index_dependant_association' do
      it 'contains the correct array for elastic_index_dependants' do
        expect(described_class.elastic_index_dependants).to contain_exactly(
          {
            association_name: :issues,
            on_change: :visibility_level
          },
          {
            association_name: :work_items,
            on_change: :visibility_level
          },
          {
            association_name: :merge_requests,
            on_change: :visibility_level
          },
          {
            association_name: :notes,
            on_change: :visibility_level
          },
          {
            association_name: :milestones,
            on_change: :visibility_level
          }
        )
      end
    end
  end

  describe 'setting up a mirror' do
    context 'when new project' do
      it 'creates import_state and sets next_execution_timestamp to now' do
        project = build(:project, :mirror, creator: create(:user))

        freeze_time do
          expect do
            project.save!
          end.to change { ProjectImportState.count }.by(1)

          expect(project.import_state.next_execution_timestamp).to be_like_time(Time.current)
        end
      end
    end

    context 'when project already exists' do
      context 'when project is not import' do
        it 'creates import_state and sets next_execution_timestamp to now' do
          project = create(:project)

          freeze_time do
            expect do
              project.update!(mirror: true, mirror_user_id: project.creator.id, import_url: generate(:url))
            end.to change { ProjectImportState.count }.by(1)

            expect(project.import_state.next_execution_timestamp).to be_like_time(Time.current)
          end
        end
      end

      context 'when project is import' do
        it 'sets current import_state next_execution_timestamp to now' do
          project = create(:project, import_url: generate(:url))

          freeze_time do
            expect do
              project.update!(mirror: true, mirror_user_id: project.creator.id)
            end.not_to change { ProjectImportState.count }

            expect(project.import_state.next_execution_timestamp).to be_like_time(Time.current)
          end
        end
      end
    end
  end

  describe '.mirrors_to_sync' do
    let(:timestamp) { Time.current }

    context 'when mirror is scheduled' do
      it 'returns empty' do
        create(:project, :mirror, :import_scheduled)

        expect(described_class.mirrors_to_sync(timestamp)).to be_empty
      end
    end

    context 'when mirror is started' do
      it 'returns empty' do
        create(:project, :mirror, :import_scheduled)

        expect(described_class.mirrors_to_sync(timestamp)).to be_empty
      end
    end

    context 'when mirror is finished' do
      let!(:project) { create(:project) }
      let!(:import_state) { create(:import_state, :mirror, :finished, project: project) }

      it 'returns project if next_execution_timestamp is not in the future' do
        expect(described_class.mirrors_to_sync(timestamp)).to match_array(project)
      end

      it 'returns empty if next_execution_timestamp is in the future' do
        import_state.update!(next_execution_timestamp: timestamp + 2.minutes)

        expect(described_class.mirrors_to_sync(timestamp)).to be_empty
      end

      context 'when a limit is applied' do
        before do
          another_project = create(:project)
          create(:import_state, :mirror, :finished, project: another_project)
        end

        it 'returns project if next_execution_timestamp is not in the future', quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/9484' do
          expect(described_class.mirrors_to_sync(timestamp, limit: 1)).to match_array(project)
        end
      end
    end

    context 'when project is failed' do
      let!(:project) { create(:project, :mirror, :import_failed) }

      it 'returns project if next_execution_timestamp is not in the future' do
        expect(described_class.mirrors_to_sync(timestamp)).to match_array(project)
      end

      it 'returns empty if next_execution_timestamp is in the future' do
        project.import_state.update!(next_execution_timestamp: timestamp + 2.minutes)

        expect(described_class.mirrors_to_sync(timestamp)).to be_empty
      end

      context 'with retry limit exceeded' do
        let!(:project) { create(:project, :mirror, :import_hard_failed) }

        it 'returns empty' do
          expect(described_class.mirrors_to_sync(timestamp)).to be_empty
        end
      end
    end

    context 'with archived project or group' do
      let_it_be_with_reload(:group) { create(:group) }
      let_it_be_with_reload(:project) { create(:project, group: group) }
      let_it_be_with_reload(:import_state) { create(:import_state, :mirror, :finished, project: project) }

      it 'returns empty with archived project' do
        project.update!(archived: true)

        expect(described_class.mirrors_to_sync(timestamp)).to be_empty
      end

      it 'returns empty with archived group' do
        group.update!(archived: true)

        expect(described_class.mirrors_to_sync(timestamp)).to be_empty
      end
    end
  end

  describe '.stuck_mirrors', :freeze_time do
    let(:time_threshold) { 10.minutes.ago }
    let_it_be_with_reload(:stuck_mirror_1) { create(:import_state, :mirror, :scheduled) }
    let_it_be_with_reload(:stuck_mirror_2) { create(:import_state, :mirror, :scheduled) }
    let_it_be_with_reload(:stuck_mirror_3) { create(:import_state, :mirror, :scheduled) }

    before do
      stuck_mirror_1.update!(last_update_scheduled_at: time_threshold)
      stuck_mirror_2.update!(last_update_scheduled_at: time_threshold)
    end

    context 'when mirrors are stuck on scheduled' do
      it 'returns all stuck mirrors' do
        expect(described_class.stuck_mirrors(time_threshold)).to contain_exactly(stuck_mirror_1.project, stuck_mirror_2.project)
      end
    end

    context 'when limit is applied' do
      let(:limit) { 1 }

      it 'returns records matching applied limit' do
        expect(described_class.stuck_mirrors(time_threshold, limit).count).to eq(1)
      end
    end
  end

  describe '.with_existing_dora_records' do
    it 'returns projects with existing DORA records for given timeframe' do
      create(:dora_daily_metrics, date: 3.years.ago)
      matched_dora = create(:dora_daily_metrics, date: 2.years.ago)
      create(:dora_daily_metrics, date: 1.year.ago)
      create(:project)

      expect(described_class.with_existing_dora_records(2.years.ago - 1.day, 2.years.ago + 1.day))
        .to contain_exactly(matched_dora.environment.project)
    end
  end

  describe '#can_store_security_reports?' do
    context 'when the feature is enabled for the namespace' do
      it 'returns true' do
        stub_licensed_features(sast: true)
        project = create(:project, :private)

        expect(project.can_store_security_reports?).to be_truthy
      end
    end

    context 'when the project is public' do
      it 'returns true' do
        stub_licensed_features(sast: false)
        project = create(:project, :public)

        expect(project.can_store_security_reports?).to be_truthy
      end
    end

    context 'when the feature is disabled for the namespace and the project is not public' do
      it 'returns false' do
        stub_licensed_features(sast: false)
        project = create(:project, :private)

        expect(project.can_store_security_reports?).to be_falsy
      end
    end
  end

  describe '#deployment_variables' do
    let(:project) { create(:project) }

    let!(:default_cluster) do
      create(
        :cluster,
        :not_managed,
        platform_type: :kubernetes,
        projects: [project],
        environment_scope: '*',
        platform_kubernetes: default_cluster_kubernetes
      )
    end

    let!(:review_env_cluster) do
      create(
        :cluster,
        :not_managed,
        platform_type: :kubernetes,
        projects: [project],
        environment_scope: 'review/*',
        platform_kubernetes: review_env_cluster_kubernetes
      )
    end

    let(:default_cluster_kubernetes) { create(:cluster_platform_kubernetes, token: 'default-AAA') }
    let(:review_env_cluster_kubernetes) { create(:cluster_platform_kubernetes, token: 'review-AAA') }

    context 'when environment name is review/name' do
      let!(:environment) { create(:environment, project: project, name: 'review/name') }

      it 'returns variables from this service' do
        expect(project.deployment_variables(environment: 'review/name'))
          .to include(key: 'KUBE_TOKEN', value: 'review-AAA', public: false, masked: true)
      end
    end

    context 'when environment name is other' do
      let!(:environment) { create(:environment, project: project, name: 'staging/name') }

      it 'returns variables from this service' do
        expect(project.deployment_variables(environment: 'staging/name'))
          .to include(key: 'KUBE_TOKEN', value: 'default-AAA', public: false, masked: true)
      end
    end
  end

  describe '#ensure_external_webhook_token' do
    let(:project) { create(:project, :repository) }

    it "sets external_webhook_token when it's missing" do
      project.update_attribute(:external_webhook_token, nil)
      expect(project.external_webhook_token).to be_blank

      project.ensure_external_webhook_token
      expect(project.external_webhook_token).to be_present
    end
  end

  describe '#push_rule' do
    subject(:project_push_rule) { project.reload_push_rule }

    let_it_be(:project) { create(:project) }
    let_it_be(:push_rule) { create(:push_rule, project: project) }

    it { is_expected.to eq(push_rule) }

    context 'push rules unlicensed' do
      before do
        stub_licensed_features(push_rules: false)
      end

      it { is_expected.to be_nil }
    end

    context 'when project has multiple push rules' do
      let!(:duplicated_push_rule) { build(:push_rule, project: project).tap { |p| p.save!(validate: false) } }

      context 'when push_rule_ordered_by_id feature flag is disabled' do
        before do
          stub_feature_flags(push_rule_ordered_by_id: false)
        end

        it 'returns a push rule without guaranteed order' do
          is_expected.to be_in([push_rule, duplicated_push_rule])
        end
      end

      context 'when push_rule_ordered_by_id feature flag is enabled' do
        before do
          stub_feature_flags(push_rule_ordered_by_id: true)
        end

        it 'returns the push rule with the lowest ID' do
          is_expected.to eq(push_rule)

          expect(project.push_rule.id).to be < duplicated_push_rule.id
        end
      end
    end
  end

  describe '#predefined_push_rule' do
    subject(:predefined_push_rule) { project.predefined_push_rule }

    context 'when inherited_push_rule_for_project is disabled' do
      before do
        stub_feature_flags(inherited_push_rule_for_project: false)
      end

      it 'return push rule' do
        expect(project).to receive(:push_rule)

        subject
      end
    end

    context 'push rules unlicensed' do
      before do
        stub_licensed_features(push_rules: false)
      end

      it { is_expected.to be_nil }
    end

    context 'push rules licensed' do
      context 'when has push rule' do
        let(:push_rule) { build(:push_rule) }

        before do
          project.push_rule = push_rule
        end

        it { is_expected.to eq(push_rule) }
      end

      context 'when has group push rule' do
        let!(:group) { create(:group) }
        let!(:group_push_rule) { create(:group_push_rule, group: group) }

        before do
          project.group = group
        end

        it { is_expected.to eq(group.group_push_rule) }
      end

      context 'when has global push rule' do
        let!(:push_rule_sample) { create(:organization_push_rule, organization: project.organization) }

        it { is_expected.to eq(push_rule_sample) }
      end
    end
  end

  describe '#should_check_index_integrity?' do
    let(:project) { build(:project, :repository) }

    subject(:should_check_index_integrity) { project.should_check_index_integrity? }

    where(:advanced_search_enabled, :repository_empty, :wiki_empty, :expected) do
      false | false | false | false
      false | false | true  | false
      false | true  | false | false
      false | true  | true  | false
      true  | false | false | true
      true  | false | true  | true
      true  | true  | false | true
      true  | true  | true  | false
    end

    with_them do
      before do
        stub_ee_application_setting(
          elasticsearch_search: advanced_search_enabled,
          elasticsearch_indexing: advanced_search_enabled
        )
        allow(project).to receive(:empty_repo?).and_return(repository_empty)
        allow(project).to receive_message_chain(:wiki, :empty?).and_return(wiki_empty)
      end

      it { is_expected.to be(expected) }
    end
  end

  context 'merge requests related settings' do
    shared_examples 'reads project column when license is unavailable' do
      before do
        stub_licensed_features(admin_merge_request_approvers_rules: false)
        project.update!(setting => true)
      end

      it 'returns the project column value without consulting the resolver', :aggregate_failures do
        expect(ComplianceManagement::MergeRequestApprovalSettings::Resolver).not_to receive(:new)

        expect(project.public_send(setting)).to be true
      end
    end

    describe '#disable_overriding_approvers_per_merge_request' do
      before do
        stub_licensed_features(admin_merge_request_approvers_rules: true)
      end

      context 'when license is available' do
        where(:resolver_value, :policy_prevents, :expected_result) do
          true  | false | false
          true  | true  | true
          false | false | true
          false | true  | true
        end

        with_them do
          before do
            allow_next_instance_of(ComplianceManagement::MergeRequestApprovalSettings::Resolver) do |resolver|
              allow(resolver).to receive(:allow_overrides_to_approver_list_per_merge_request)
                .and_return(ComplianceManagement::MergeRequestApprovalSettings::Setting.new(
                  value: resolver_value,
                  locked: false,
                  inherited_from: nil
                ))
            end

            allow(project).to receive(:policy_prevents_editing_approval_rules?).and_return(policy_prevents)
          end

          it { expect(project.disable_overriding_approvers_per_merge_request).to be expected_result }
        end

        it 'memoizes the result' do
          allow_next_instance_of(ComplianceManagement::MergeRequestApprovalSettings::Resolver) do |resolver|
            allow(resolver).to receive(:allow_overrides_to_approver_list_per_merge_request)
              .and_return(ComplianceManagement::MergeRequestApprovalSettings::Setting.new(
                value: true,
                locked: false,
                inherited_from: nil
              ))
          end

          expect(project).to receive(:policy_prevents_editing_approval_rules?).once.and_return(true)

          2.times { project.disable_overriding_approvers_per_merge_request }
        end
      end

      it_behaves_like 'reads project column when license is unavailable' do
        let(:setting) { :disable_overriding_approvers_per_merge_request }
      end
    end

    describe '#policy_prevents_editing_approval_rules?' do
      subject { project.policy_prevents_editing_approval_rules? }

      let!(:configuration) do
        create(:security_orchestration_policy_configuration, project: project)
      end

      let!(:policy) do
        create(:security_policy,
          :prevent_editing_approval_rules,
          security_orchestration_policy_configuration: configuration,
          linked_projects: [project])
      end

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it { is_expected.to be true }

      context 'when security_orchestration_policies is not available' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it { is_expected.to be false }
      end

      context 'when the policy is in warn mode' do
        before do
          policy.update!(content: policy.content.merge('enforcement_type' => 'warn'))
        end

        it { is_expected.to be false }
      end

      context 'when no policies enforce the setting' do
        before do
          policy.update!(content: { approval_settings: { prevent_editing_approval_rules: false } })
        end

        it { is_expected.to be false }
      end
    end

    shared_examples 'a predicate wrapper method' do
      where(:wrapped_method_return, :subject_return) do
        true  | true
        false | false
        nil   | false
      end

      with_them do
        it 'returns the expected boolean value' do
          expect(project)
            .to receive(wrapped_method)
            .and_return(wrapped_method_return)

          expect(project.send("#{wrapped_method}?")).to be(subject_return)
        end
      end
    end

    describe '#disable_overriding_approvers_per_merge_request?' do
      it_behaves_like 'a predicate wrapper method' do
        let(:wrapped_method) { :disable_overriding_approvers_per_merge_request }
      end
    end

    describe '#merge_requests_disable_committers_approval' do
      before do
        stub_licensed_features(admin_merge_request_approvers_rules: true)
      end

      it 'returns false when the resolver returns true' do
        allow_next_instance_of(ComplianceManagement::MergeRequestApprovalSettings::Resolver) do |resolver|
          allow(resolver).to receive(:allow_committer_approval)
            .and_return(ComplianceManagement::MergeRequestApprovalSettings::Setting.new(
              value: true,
              locked: false,
              inherited_from: nil
            ))
        end

        expect(project.merge_requests_disable_committers_approval).to be false
      end

      it 'returns true when the resolver returns false' do
        allow_next_instance_of(ComplianceManagement::MergeRequestApprovalSettings::Resolver) do |resolver|
          allow(resolver).to receive(:allow_committer_approval)
            .and_return(ComplianceManagement::MergeRequestApprovalSettings::Setting.new(
              value: false,
              locked: false,
              inherited_from: nil
            ))
        end

        expect(project.merge_requests_disable_committers_approval).to be true
      end

      it_behaves_like 'reads project column when license is unavailable' do
        let(:setting) { :merge_requests_disable_committers_approval }
      end
    end

    describe '#merge_requests_disable_committers_approval?' do
      it_behaves_like 'a predicate wrapper method' do
        let(:wrapped_method) { :merge_requests_disable_committers_approval }
      end
    end

    describe '#require_reauthentication_to_approve?' do
      let_it_be(:root_ancestor) { create(:group) }
      let_it_be(:sub_group) { create(:group, parent: root_ancestor) }

      before do
        allow(project).to receive(:group).and_return(sub_group)
      end

      it 'returns true when the resolver returns true' do
        expect(ComplianceManagement::MergeRequestApprovalSettings::Resolver)
          .to receive(:new)
          .with(root_ancestor, project: project)

        allow_next_instance_of(ComplianceManagement::MergeRequestApprovalSettings::Resolver) do |resolver|
          # internally still maps to require_password_to_approve so mock that call
          allow(resolver).to receive(:require_password_to_approve)
            .and_return(ComplianceManagement::MergeRequestApprovalSettings::Setting.new(
              value: true,
              locked: false,
              inherited_from: nil
            ))
        end

        expect(project.require_reauthentication_to_approve).to be true
      end

      it 'returns false when the resolver returns false' do
        expect(ComplianceManagement::MergeRequestApprovalSettings::Resolver)
          .to receive(:new)
          .with(root_ancestor, project: project)

        allow_next_instance_of(ComplianceManagement::MergeRequestApprovalSettings::Resolver) do |resolver|
          # internally still maps to require_password_to_approve so mock that call
          allow(resolver).to receive(:require_password_to_approve)
            .and_return(ComplianceManagement::MergeRequestApprovalSettings::Setting.new(
              value: false,
              locked: false,
              inherited_from: nil
            ))
        end

        expect(project.require_reauthentication_to_approve).to be false
      end
    end

    describe '#require_password_to_approve?' do
      let_it_be(:root_ancestor) { create(:group) }
      let_it_be(:sub_group) { create(:group, parent: root_ancestor) }

      before do
        allow(project).to receive(:group).and_return(sub_group)
      end

      it 'returns true when the resolver returns true' do
        expect(ComplianceManagement::MergeRequestApprovalSettings::Resolver)
          .to receive(:new)
          .with(root_ancestor, project: project)

        allow_next_instance_of(ComplianceManagement::MergeRequestApprovalSettings::Resolver) do |resolver|
          allow(resolver).to receive(:require_password_to_approve)
            .and_return(ComplianceManagement::MergeRequestApprovalSettings::Setting.new(
              value: true,
              locked: false,
              inherited_from: nil
            ))
        end

        expect(project.require_password_to_approve).to be true
      end

      it 'returns false when the resolver returns false' do
        expect(ComplianceManagement::MergeRequestApprovalSettings::Resolver)
          .to receive(:new)
          .with(root_ancestor, project: project)

        allow_next_instance_of(ComplianceManagement::MergeRequestApprovalSettings::Resolver) do |resolver|
          allow(resolver).to receive(:require_password_to_approve)
            .and_return(ComplianceManagement::MergeRequestApprovalSettings::Setting.new(
              value: false,
              locked: false,
              inherited_from: nil
            ))
        end

        expect(project.require_password_to_approve).to be false
      end

      it 'sets require_reauthentication_to_approve along with require_password_to_approve' do
        project.require_password_to_approve = false

        expect(project.project_setting.require_reauthentication_to_approve).to be_falsy
        expect(project.require_password_to_approve).to be_falsy

        project.require_password_to_approve = true

        expect(project.project_setting.require_reauthentication_to_approve).to be_truthy

        project.save!
        project.reload

        # persisted the change
        expect(project.project_setting.require_reauthentication_to_approve).to be_truthy
        expect(project.require_password_to_approve).to be_truthy
      end

      it 'sets require_password_to_approve along with require_reauthentication_to_approve' do
        project.require_reauthentication_to_approve = false

        expect(project.project_setting.require_reauthentication_to_approve).to be_falsy
        expect(project.require_password_to_approve).to be_falsy

        project.require_reauthentication_to_approve = true

        expect(project.require_password_to_approve).to be_truthy
        expect(project.project_setting.require_reauthentication_to_approve).to be_truthy

        project.save!
        project.reload

        # persisted the change
        expect(project.project_setting.require_reauthentication_to_approve).to be_truthy
        expect(project.require_password_to_approve).to be_truthy
      end
    end

    describe '#merge_requests_author_approval' do
      let(:setting) { :merge_requests_author_approval }
      let(:application_setting) { :prevent_merge_requests_author_approval }

      before do
        stub_licensed_features(admin_merge_request_approvers_rules: true)
      end

      it 'returns true when the resolver returns true' do
        allow_next_instance_of(ComplianceManagement::MergeRequestApprovalSettings::Resolver) do |resolver|
          allow(resolver).to receive(:allow_author_approval)
            .and_return(ComplianceManagement::MergeRequestApprovalSettings::Setting.new(
              value: true,
              locked: false,
              inherited_from: nil
            ))
        end

        expect(project.merge_requests_author_approval).to be true
      end

      it 'returns false when the resolver returns false' do
        allow_next_instance_of(ComplianceManagement::MergeRequestApprovalSettings::Resolver) do |resolver|
          allow(resolver).to receive(:allow_author_approval)
            .and_return(ComplianceManagement::MergeRequestApprovalSettings::Setting.new(
              value: false,
              locked: false,
              inherited_from: nil
            ))
        end

        expect(project.merge_requests_author_approval).to be false
      end

      it_behaves_like 'reads project column when license is unavailable' do
        let(:setting) { :merge_requests_author_approval }
      end
    end

    describe '#merge_requests_author_approval?' do
      it_behaves_like 'a predicate wrapper method' do
        let(:wrapped_method) { :merge_requests_author_approval }
      end
    end
  end

  describe '#has_active_hooks?' do
    context "with group hooks" do
      let(:group) { create(:group) }
      let(:project) { create(:project, namespace: group) }
      let!(:group_hook) { create(:group_hook, group: group, push_events: true) }

      before do
        stub_licensed_features(group_webhooks: true)
      end

      it 'returns true' do
        expect(project.has_active_hooks?).to be(true)
        expect(project.has_group_hooks?).to be(true)
      end
    end

    context 'with no group hooks' do
      it 'returns false' do
        expect(project.has_active_hooks?).to be(false)
        expect(project.has_group_hooks?).to be(false)
      end
    end
  end

  describe '#has_group_hooks?' do
    subject { project.has_group_hooks? }

    let(:project) { create(:project) }

    it { is_expected.to be(false) }

    context 'project is in a group' do
      let(:group) { create(:group) }
      let(:project) { create(:project, namespace: group) }

      shared_examples 'returns false when the feature is not available' do
        specify do
          stub_licensed_features(group_webhooks: false)

          expect(subject).to be(false)
        end
      end

      it_behaves_like 'returns false when the feature is not available'

      it { is_expected.to be(false) }

      context 'the group has hooks' do
        let!(:group_hook) { create(:group_hook, group: group, push_events: true) }

        it { is_expected.to be(true) }

        it_behaves_like 'returns false when the feature is not available'

        context 'but the hook is not in scope' do
          subject { project.has_group_hooks?(:issue_hooks) }

          it_behaves_like 'returns false when the feature is not available'

          it { is_expected.to be(false) }
        end

        it 'caches matching integrations' do
          create(:group_hook, group: group, push_events: true, merge_requests_events: false)

          expect(project.has_group_hooks?(:merge_request_hooks)).to be(false)
          expect(project.has_group_hooks?).to be(true)

          count = ActiveRecord::QueryRecorder.new do
            expect(project.has_group_hooks?(:merge_request_hooks)).to be(false)
            expect(project.has_group_hooks?).to be(true)
          end.count

          expect(count).to eq(0)
        end
      end

      context 'the group inherits a hook' do
        let(:parent_group) { create(:group) }
        let!(:group_hook) { create(:group_hook, group: parent_group) }
        let(:group) { create(:group, parent: parent_group) }

        it_behaves_like 'returns false when the feature is not available'

        it { is_expected.to be(true) }
      end
    end
  end

  describe '#execute_external_compliance_hooks' do
    let_it_be(:rule) { create(:external_status_check) }

    it 'enqueues the correct number of workers' do
      allow(rule).to receive(:async_execute).once

      rule.project.execute_external_compliance_hooks({})
    end
  end

  describe "#execute_hooks" do
    context "group hooks" do
      let_it_be_with_reload(:group) { create(:group) }
      let_it_be_with_reload(:project) { create(:project, namespace: group) }
      let_it_be_with_reload(:group_hook) { create(:group_hook, group: group, resource_access_token_events: true) }

      it 'does not execute the hook when the feature is disabled' do
        stub_licensed_features(group_webhooks: false)

        expect(project).not_to receive(:group_hooks)
        expect(WebHookService).not_to receive(:new).with(instance_of(GroupHook), anything, anything)

        project.execute_hooks(some: 'info')
      end

      context 'when group_webhooks feature is enabled' do
        before do
          stub_licensed_features(group_webhooks: true)
        end

        let(:fake_wh_service) { double }

        shared_examples 'triggering group webhook' do
          it 'executes the hook' do
            expect(fake_wh_service).to receive(:async_execute).once

            expect(WebHookService)
              .to receive(:new)
              .with(
                group_hook,
                { some: 'info' },
                'push_hooks',
                idempotency_key: anything
              ) { fake_wh_service }

            project.execute_hooks(some: 'info')
          end
        end

        context 'when resource access token hooks for expiry notification' do
          let(:wh_service) { double(async_execute: true) }

          context 'when interval is seven days' do
            let(:data) { { interval: :seven_days } }

            it 'executes webhook' do
              expect(WebHookService)
                .to receive(:new)
                .with(group_hook, data, 'resource_access_token_hooks', idempotency_key: anything)
                .and_return(wh_service)

              project.execute_hooks(data, :resource_access_token_hooks)
            end
          end

          context 'when setting extended_grat_expiry_webhooks_execute is disabled' do
            before do
              group.namespace_settings.update!(extended_grat_expiry_webhooks_execute: false)
            end

            context 'when interval is thirty days' do
              let(:data) { { interval: :thirty_days } }

              it 'does not execute the hook' do
                expect(WebHookService).not_to receive(:new)

                project.execute_hooks(data, :resource_access_token_hooks)
              end
            end

            context 'when interval is sixty days' do
              let(:data) { { interval: :sixty_days } }

              it 'does not execute the hook' do
                expect(WebHookService).not_to receive(:new)

                project.execute_hooks(data, :resource_access_token_hooks)
              end
            end
          end

          context 'when setting extended_grat_expiry_webhooks_execute is enabled' do
            before do
              group.namespace_settings.update!(extended_grat_expiry_webhooks_execute: true)
            end

            context 'when interval is thirty days' do
              let(:data) { { interval: :thirty_days } }

              it 'executes webhook' do
                expect(WebHookService)
                  .to receive(:new)
                  .with(group_hook, data, 'resource_access_token_hooks', idempotency_key: anything)
                  .and_return(wh_service)

                project.execute_hooks(data, :resource_access_token_hooks)
              end
            end

            context 'when interval is sixty days' do
              let(:data) { { interval: :sixty_days } }

              it 'executes webhook' do
                expect(WebHookService)
                  .to receive(:new)
                  .with(group_hook, data, 'resource_access_token_hooks', idempotency_key: anything)
                  .and_return(wh_service)

                project.execute_hooks(data, :resource_access_token_hooks)
              end
            end
          end
        end

        context 'when the hook defines a branch filter for push events' do
          let(:wh_service) { double(async_execute: true) }
          let(:selective_hook) { create(:group_hook, group: group, push_events: true, push_events_branch_filter: 'on-this-branch-only') }

          it 'respects the branch filter' do
            expect(WebHookService)
              .to receive(:new)
              .twice
              .with(
                group_hook,
                Hash,
                'push_hooks',
                idempotency_key: anything
              ).and_return(wh_service)

            expect(WebHookService)
              .to receive(:new)
              .once
              .with(
                selective_hook,
                a_hash_including(note: 'matches-filter'),
                'push_hooks',
                idempotency_key: anything
              ).and_return(wh_service)

            project.execute_hooks({ note: 'matches-filter', ref: 'refs/heads/on-this-branch-only' }, :push_hooks)
            project.execute_hooks({ note: 'default-branch', ref: 'refs/heads/master' }, :push_hooks)
            project.execute_hooks({ note: 'not-push', ref: 'refs/heads/on-this-branch-only' }, :deployment_hooks)
          end
        end

        it_behaves_like 'triggering group webhook'

        context 'in sub group' do
          let(:sub_group) { create :group, parent: group }
          let(:sub_sub_group) { create :group, parent: sub_group }
          let(:project) { create(:project, namespace: sub_sub_group) }

          it_behaves_like 'triggering group webhook'
        end
      end
    end
  end

  describe '#execute_integrations' do
    let(:integration) { create(:integrations_slack, push_events: true) }

    subject(:execute_integrations) { integration.project.execute_integrations(kind_of(Hash)) }

    shared_examples 'executes the integration' do
      specify do
        expect_next_found_instance_of(integration.class) do |instance|
          expect(instance).to receive(:async_execute).once
        end

        execute_integrations
      end
    end

    context 'when application settings do not allow all integrations' do
      before do
        stub_application_setting(allow_all_integrations: false)
        stub_licensed_features(integrations_allow_list: true)
      end

      it 'does not execute the integration' do
        expect(integration.class).not_to receive(:new)

        execute_integrations
      end

      context 'when integration is in allowlist' do
        before do
          stub_application_setting(allowed_integrations: [integration.to_param])
        end

        it_behaves_like 'executes the integration'
      end

      context 'when license is insufficient' do
        before do
          stub_licensed_features(integrations_allow_list: false)
        end

        it_behaves_like 'executes the integration'
      end
    end
  end

  describe '#allowed_to_share_with_group?' do
    let(:project) { create(:project) }

    it "returns true" do
      expect(project.allowed_to_share_with_group?).to be_truthy
    end

    it "returns false" do
      project.namespace.update!(share_with_group_lock: true)
      expect(project.allowed_to_share_with_group?).to be_falsey
    end
  end

  describe '#membership_locked?' do
    let(:project) { build_stubbed(:project, group: group) }
    let(:group) { nil }

    context 'when project has no group' do
      let(:project) { described_class.new }

      it 'is false' do
        expect(project).not_to be_membership_locked
      end
    end

    context 'with group_membership_lock enabled' do
      let(:group) { build_stubbed(:group, membership_lock: true) }

      it 'is true' do
        expect(project).to be_membership_locked
      end
    end

    context 'with group_membership_lock disabled' do
      let(:group) { build_stubbed(:group, membership_lock: false) }

      it 'is false' do
        expect(project).not_to be_membership_locked
      end
    end
  end

  describe '#feature_available?' do
    let(:namespace) { build(:namespace) }
    let(:project) { build(:project, namespace: namespace) }
    let(:group) { build(:group) }
    let(:group_project) { build(:project, namespace: group) }
    let(:user) { build(:user) }
    let(:plan_license) { nil }

    subject { project.feature_available?(feature, user) }

    context 'when feature symbol is included on Namespace features code' do
      before do
        stub_application_setting('check_namespace_plan?' => check_namespace_plan)
        allow(Gitlab).to receive(:com?).and_return(true)
        stub_licensed_features(feature => allowed_on_global_license)
        allow(namespace).to receive(:plan) { plan_license }
      end

      GitlabSubscriptions::Features::ALL_FEATURES.each do |feature_sym|
        context feature_sym.to_s do
          let(:feature) { feature_sym }

          unless GitlabSubscriptions::Features::GLOBAL_FEATURES.include?(feature_sym)
            context "checking #{feature_sym} availability both on Global and Namespace license" do
              let(:check_namespace_plan) { true }

              context 'allowed by Plan License AND Global License' do
                let(:allowed_on_global_license) { true }
                let(:plan_license) { build(:ultimate_plan) }

                before do
                  allow(namespace).to receive(:actual_plan) { plan_license }
                end

                context 'with group namespace' do
                  let(:namespace) { group }
                  let(:project) { group_project }

                  it 'returns true' do
                    is_expected.to be(true)
                  end
                end

                context 'with user namespace' do
                  it 'respects group-only feature restrictions' do
                    expected = ::GitlabSubscriptions::Features::GROUP_ONLY_LICENSED_FEATURES.include?(feature_sym) ? false : true
                    is_expected.to eq(expected)
                  end
                end
              end

              context 'not allowed by Plan License but project and namespace are public' do
                let(:allowed_on_global_license) { true }
                let(:plan_license) { build(:bronze_plan) }

                before do
                  allow(namespace).to receive(:public?).and_return(true)
                  allow(project).to receive(:public?).and_return(true)
                end

                context 'with group namespace' do
                  let(:namespace) { group }
                  let(:project) { group_project }

                  it 'returns true' do
                    is_expected.to be(true)
                  end
                end

                context 'with user namespace' do
                  it 'respects group-only feature restrictions' do
                    expected = ::GitlabSubscriptions::Features::GROUP_ONLY_LICENSED_FEATURES.include?(feature_sym) ? false : true
                    is_expected.to eq(expected)
                  end
                end
              end

              unless GitlabSubscriptions::Features.plans_with_feature(feature_sym).include?(License::STARTER_PLAN)
                context 'not allowed by Plan License' do
                  let(:allowed_on_global_license) { true }
                  let(:plan_license) { build(:bronze_plan) }

                  context 'with group namespace' do
                    let(:namespace) { group }
                    let(:project) { group_project }

                    it 'returns false' do
                      is_expected.to be(false)
                    end
                  end

                  context 'with user namespace' do
                    it 'returns false' do
                      is_expected.to be(false)
                    end
                  end
                end
              end

              context 'not allowed by Global License' do
                let(:allowed_on_global_license) { false }
                let(:plan_license) { build(:ultimate_plan) }

                context 'with group namespace' do
                  let(:namespace) { group }
                  let(:project) { group_project }

                  it 'returns false' do
                    is_expected.to be(false)
                  end
                end

                context 'with user namespace' do
                  it 'returns false' do
                    is_expected.to be(false)
                  end
                end
              end
            end
          end

          context "when checking #{feature_sym} only for Global license" do
            let(:check_namespace_plan) { false }

            context 'allowed by Global License' do
              let(:allowed_on_global_license) { true }

              context 'with group namespace' do
                let(:namespace) { group }
                let(:project) { group_project }

                it 'returns true' do
                  is_expected.to be(true)
                end
              end

              context 'with user namespace' do
                it 'respects group-only feature restrictions' do
                  expected = ::GitlabSubscriptions::Features::GROUP_ONLY_LICENSED_FEATURES.include?(feature_sym) ? false : true
                  is_expected.to eq(expected)
                end
              end
            end

            context 'not allowed by Global License' do
              let(:allowed_on_global_license) { false }

              context 'with group namespace' do
                let(:namespace) { group }
                let(:project) { group_project }

                it 'returns false' do
                  is_expected.to be(false)
                end
              end

              context 'with user namespace' do
                it 'returns false' do
                  is_expected.to be(false)
                end
              end
            end
          end
        end
      end
    end

    it 'only loads licensed availability once' do
      expect(project).to receive(:load_licensed_feature_available)
        .once.and_call_original

      with_license_feature_cache do
        2.times { project.feature_available?(:push_rules) }
      end
    end

    context 'when feature symbol is not included on Namespace features code' do
      let(:feature) { :issues }

      it 'checks availability of licensed feature' do
        expect(project.project_feature).to receive(:feature_available?).with(feature, user)

        subject
      end
    end

    context 'legacy open-source license' do
      let(:feature) { :sast }

      before do
        stub_application_setting(check_namespace_plan: true)
        stub_licensed_features(feature => true)
      end

      context 'public projects' do
        let(:project) { build(:project, :public, namespace: namespace) }

        where(:gitlab_dot_com?, :legacy_open_source_license_available_ff, :ultimate_features) do
          true  | true  | true
          true  | false | false
          false | true  | true
          false | false | true
        end

        with_them do
          before do
            allow(Gitlab).to receive(:com?).and_return(gitlab_dot_com?)
            stub_feature_flags(legacy_open_source_license_available: legacy_open_source_license_available_ff)
          end

          it 'offers ultimate features' do
            is_expected.to eq(ultimate_features)
          end
        end
      end
    end
  end

  describe '#fetch_mirror' do
    where(:import_url, :auth_method, :expected) do
      'http://foo:bar@example.com' | 'password'       | 'http://foo:bar@example.com'
      'ssh://foo:bar@example.com'  | 'password'       | 'ssh://foo:bar@example.com'
      'ssh://foo:bar@example.com'  | 'ssh_public_key' | 'ssh://foo@example.com'
    end

    with_them do
      let(:project) { build(:project, :mirror, import_url: import_url, import_data_attributes: { auth_method: auth_method }) }

      specify do
        expect(project.repository).to receive(:fetch_upstream).with(expected, forced: false, resolved_address: '')
        project.fetch_mirror
      end
    end
  end

  describe 'updating import_url' do
    it 'removes previous remote' do
      project = create(:project, :repository, :mirror)

      project.update!(import_url: "http://test.com")
    end
  end

  describe '#any_online_runners?', :freeze_time do
    let!(:shared_runner) { create(:ci_runner, :instance, :online) }

    it { expect(project.any_online_runners?).to be_truthy }

    context 'with used compute minutes' do
      let(:namespace) { create(:namespace, :with_used_build_minutes_limit) }
      let(:project) { create(:project, namespace: namespace, shared_runners_enabled: true) }

      it 'does not have any online runners' do
        expect(project.any_online_runners?).to be_falsey
      end
    end
  end

  describe '#shared_runners_available?' do
    subject { project.shared_runners_available? }

    context 'with used compute minutes' do
      let(:namespace) { create(:namespace, :with_used_build_minutes_limit) }
      let(:project) do
        create(:project, namespace: namespace, shared_runners_enabled: true)
      end

      it 'shared runners are not available' do
        expect(project.shared_runners_available?).to be_falsey
      end
    end

    context 'without used compute minutes' do
      let(:namespace) { create(:namespace, :with_not_used_build_minutes_limit) }
      let(:project) do
        create(:project, namespace: namespace, shared_runners_enabled: true)
      end

      it 'shared runners are not available' do
        expect(project.shared_runners_available?).to be_truthy
      end
    end
  end

  describe '#ai_catalog_available?' do
    let(:user) { build(:user) }

    subject(:ai_catalog_available) { project.ai_catalog_available? }

    where(:stage_check_available, :duo_features_enabled, :expectation) do
      true  | true | true
      true  | false | false
      false | true | false
      false | false | false
    end

    with_them do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?)
          .with(project, :ai_catalog).and_return(stage_check_available)
        project.duo_features_enabled = duo_features_enabled
      end

      it { is_expected.to be expectation }
    end
  end

  describe '#root_namespace' do
    let(:project) { build(:project, namespace: parent) }

    subject { project.root_namespace }

    context 'when namespace has parent group' do
      let(:root_ancestor) { create(:group) }
      let(:parent) { create(:group, parent: root_ancestor) }

      it 'returns root ancestor' do
        is_expected.to eq(root_ancestor)
      end
    end

    context 'when namespace is root ancestor' do
      let(:parent) { create(:group) }

      it 'returns current namespace' do
        is_expected.to eq(parent)
      end
    end
  end

  describe '#shared_runners_limit_namespace' do
    let_it_be(:root_ancestor) { create(:group) }
    let_it_be(:group) { create(:group, parent: root_ancestor) }

    let(:project) { create(:project, namespace: group) }

    subject { project.shared_runners_limit_namespace }

    it 'returns root namespace' do
      is_expected.to eq(root_ancestor)
    end
  end

  describe '#shared_runners_minutes_limit_enabled?' do
    let(:project) { create(:project) }

    subject { project.shared_runners_minutes_limit_enabled? }

    before do
      allow(project.namespace).to receive(:shared_runners_minutes_limit_enabled?)
        .and_return(true)
    end

    context 'with shared runners enabled' do
      before do
        project.shared_runners_enabled = true
      end

      context 'for public project' do
        before do
          project.visibility_level = Project::PUBLIC
        end

        it { is_expected.to be_truthy }
      end

      context 'for internal project' do
        before do
          project.visibility_level = Project::INTERNAL
        end

        it { is_expected.to be_truthy }
      end

      context 'for private project' do
        before do
          project.visibility_level = Project::INTERNAL
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'without shared runners' do
      before do
        project.shared_runners_enabled = false
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#approvals_before_merge' do
    where(:license_value, :db_value, :expected) do
      true  | 5 | 5
      true  | 0 | 0
      false | 5 | 0
      false | 0 | 0
    end

    with_them do
      let(:project) { build(:project, approvals_before_merge: db_value) }

      subject { project.approvals_before_merge }

      before do
        stub_licensed_features(merge_request_approvers: license_value)
      end

      it { is_expected.to eq(expected) }
    end
  end

  describe "#reset_approvals_on_push?" do
    let_it_be(:root_ancestor) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: root_ancestor) }

    before do
      allow(project).to receive(:group).and_return(sub_group)
    end

    it 'returns false when the resolver returns true' do
      expect(ComplianceManagement::MergeRequestApprovalSettings::Resolver)
        .to receive(:new)
        .with(root_ancestor, project: project)

      allow_next_instance_of(ComplianceManagement::MergeRequestApprovalSettings::Resolver) do |resolver|
        allow(resolver).to receive(:retain_approvals_on_push)
          .and_return(ComplianceManagement::MergeRequestApprovalSettings::Setting.new(
            value: true,
            locked: false,
            inherited_from: nil
          ))
      end

      expect(project.reset_approvals_on_push).to be false
    end

    it 'returns true when the resolver returns false' do
      expect(ComplianceManagement::MergeRequestApprovalSettings::Resolver)
        .to receive(:new)
        .with(root_ancestor, project: project)

      allow_next_instance_of(ComplianceManagement::MergeRequestApprovalSettings::Resolver) do |resolver|
        allow(resolver).to receive(:retain_approvals_on_push)
          .and_return(ComplianceManagement::MergeRequestApprovalSettings::Setting.new(
            value: false,
            locked: false,
            inherited_from: nil
          ))
      end

      expect(project.reset_approvals_on_push).to be true
    end
  end

  describe '#approvals_before_merge' do
    where(:license_value, :db_value, :expected) do
      true  | 5 | 5
      true  | 0 | 0
      false | 5 | 0
      false | 0 | 0
    end

    with_them do
      let(:project) { build(:project, approvals_before_merge: db_value) }

      subject { project.approvals_before_merge }

      before do
        stub_licensed_features(merge_request_approvers: license_value)
      end

      it { is_expected.to eq(expected) }
    end
  end

  describe '#visible_user_defined_rules' do
    let(:project) { create(:project) }
    let!(:approval_rules) { create_list(:approval_project_rule, 2, project: project) }
    let!(:any_approver_rule) { create(:approval_project_rule, rule_type: :any_approver, project: project) }
    let(:branch) { nil }

    subject { project.visible_user_defined_rules(branch: branch) }

    before do
      stub_licensed_features(multiple_approval_rules: true)
    end

    it 'returns all approval rules' do
      expect(subject).to eq([any_approver_rule, *approval_rules])
    end

    context 'when multiple approval rules is not available' do
      before do
        stub_licensed_features(multiple_approval_rules: false)
      end

      it 'returns the first approval rule' do
        expect(subject).to eq([any_approver_rule])
      end
    end

    context 'when branch is provided' do
      let(:branch) { 'master' }

      it 'caches the rules' do
        expect(project).to receive(:user_defined_rules).and_call_original
        subject

        expect(project).not_to receive(:user_defined_rules)
        subject
      end
    end
  end

  describe '#visible_user_defined_inapplicable_rules' do
    let_it_be_with_refind(:project) { create(:project) }

    let_it_be_with_reload(:rule) { create(:approval_project_rule, project: project) }
    let_it_be_with_reload(:another_rule) { create(:approval_project_rule, project: project) }

    context 'when multiple approval rules is available' do
      before do
        stub_licensed_features(multiple_approval_rules: true)
      end

      let(:protected_branch) { create(:protected_branch, project: project, name: 'stable-*') }
      let(:another_protected_branch) { create(:protected_branch, project: project, name: 'test-*') }

      context 'when rules are scoped' do
        before do
          rule.update!(protected_branches: [protected_branch])
          another_rule.update!(protected_branches: [another_protected_branch])
        end

        it 'returns rules that are not applicable to target_branch' do
          expect(project.visible_user_defined_inapplicable_rules('stable-1'))
            .to match_array([another_rule])
        end
      end

      context 'when rules are not scoped' do
        it 'returns empty array' do
          expect(project.visible_user_defined_inapplicable_rules('stable-1')).to be_empty
        end
      end
    end

    context 'when multiple approval rules is not available' do
      before do
        stub_licensed_features(multiple_approval_rules: false)
      end

      it 'returns empty array' do
        expect(project.visible_user_defined_inapplicable_rules('stable-1')).to be_empty
      end
    end
  end

  describe '#min_fallback_approvals' do
    let(:project) { create(:project) }

    before do
      create(:approval_project_rule, project: project, rule_type: :any_approver, approvals_required: 2)
      create(:approval_project_rule, project: project, approvals_required: 2)
      create(:approval_project_rule, project: project, approvals_required: 3)

      stub_licensed_features(multiple_approval_rules: true)
    end

    it 'returns the maximum requirement' do
      expect(project.min_fallback_approvals).to eq(3)
    end

    it 'returns the first rule requirement if there is a rule' do
      stub_licensed_features(multiple_approval_rules: false)

      expect(project.min_fallback_approvals).to eq(2)
    end
  end

  describe '#merge_requests_require_code_owner_approval?' do
    let(:project) { build(:project) }

    where(:feature_available, :feature_enabled, :approval_required) do
      true  | true  | true
      false | true  | false
      true  | false | false
    end

    with_them do
      before do
        stub_licensed_features(code_owner_approval_required: feature_available)

        if feature_enabled
          create(:protected_branch,
            project: project,
            code_owner_approval_required: true)
        end
      end

      it 'requires code owner approval when needed' do
        expect(project.merge_requests_require_code_owner_approval?).to eq(approval_required)
      end
    end
  end

  describe '#branch_requires_code_owner_approval?' do
    let(:protected_branch) { create(:protected_branch, code_owner_approval_required: false) }
    let(:protected_branch_needing_approval) { create(:protected_branch, code_owner_approval_required: true) }

    context "when feature is enabled" do
      before do
        stub_licensed_features(code_owner_approval_required: true)
      end

      it 'returns true when code owner approval is required' do
        project = protected_branch_needing_approval.project

        expect(project.branch_requires_code_owner_approval?(protected_branch_needing_approval.name)).to be(true)
      end

      it 'returns false when code owner approval is not required' do
        project = protected_branch.project

        expect(project.branch_requires_code_owner_approval?(protected_branch.name)).to be(false)
      end
    end

    context "when feature is not enabled" do
      before do
        stub_licensed_features(code_owner_approval_required: false)
      end

      it 'returns true when code owner approval is required' do
        project = protected_branch_needing_approval.project

        expect(project.branch_requires_code_owner_approval?(protected_branch_needing_approval.name)).to be(false)
      end

      it 'returns false when code owner approval is not required' do
        project = protected_branch.project

        expect(project.branch_requires_code_owner_approval?(protected_branch.name)).to be(false)
      end
    end
  end

  describe '#disabled_integrations' do
    let(:project) { build(:project) }

    subject { project.disabled_integrations }

    context 'github' do
      where(:license_feature, :disabled_integrations) do
        :github_integration | %w[github]
      end

      with_them do
        context 'when feature is available' do
          before do
            stub_licensed_features(license_feature => true)
          end

          it { is_expected.not_to include(*disabled_integrations) }
        end

        context 'when feature is unavailable' do
          before do
            stub_licensed_features(license_feature => false)
          end

          it { is_expected.to include(*disabled_integrations) }
        end
      end
    end

    context 'artifact registry' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      it { is_expected.not_to include('google_cloud_platform_artifact_registry') }

      context 'when google artifact registry feature is unavailable' do
        before do
          stub_saas_features(google_cloud_support: false)
        end

        it { is_expected.to include('google_cloud_platform_artifact_registry') }
      end
    end

    context 'workload identity federation' do
      it { is_expected.to include('google_cloud_platform_workload_identity_federation') }

      context 'when google artifact registry feature is available' do
        before do
          stub_saas_features(google_cloud_support: true)
        end

        it { is_expected.not_to include('google_cloud_platform_workload_identity_federation') }
      end
    end
  end

  describe '#pull_mirror_available?' do
    let(:project) { create(:project) }

    context 'when mirror global setting is enabled' do
      it 'returns true' do
        expect(project.pull_mirror_available?).to be(true)
      end
    end

    context 'when mirror global setting is disabled' do
      before do
        stub_application_setting(mirror_available: false)
      end

      it 'returns true when overridden' do
        project.pull_mirror_available_overridden = true

        expect(project.pull_mirror_available?).to be(true)
      end

      it 'returns false when not overridden' do
        expect(project.pull_mirror_available?).to be(false)
      end
    end
  end

  describe '#username_only_import_url' do
    where(:import_url, :username, :expected_import_url) do
      '' | 'foo' | ''
      '' | ''    | ''
      '' | nil   | ''

      nil | 'foo' | nil
      nil | ''    | nil
      nil | nil   | nil

      'http://example.com' | 'foo' | 'http://foo@example.com'
      'http://example.com' | ''    | 'http://example.com'
      'http://example.com' | nil   | 'http://example.com'
    end

    with_them do
      let(:project) { build(:project, import_url: import_url, import_data_attributes: { user: username, password: 'password' }) }

      it { expect(project.username_only_import_url).to eq(expected_import_url) }
    end
  end

  describe '#username_only_import_url=' do
    it 'sets the import url and username', :aggregate_failures do
      project = build(:project, import_url: 'http://user@example.com')

      expect(project.unsafe_import_url).to eq('http://user@example.com')
      expect(project.import_data.user).to eq('user')
    end

    context 'when the URL is changed' do
      it 'clears the stored password', :aggregate_failures do
        project = build(:project, import_url: 'https://user:pass@old.example.com')
        project.username_only_import_url = 'https://user@new.example.com'

        expect(project.unsafe_import_url).to eq('https://user@new.example.com')
        expect(project.import_data.password).to be_nil
      end
    end

    context 'when the URL includes a password' do
      it 'clears the stored password because the URL password is not stored', :aggregate_failures do
        project = build(:project, import_url: 'https://user:pass@old.example.com')
        project.username_only_import_url = 'https://user:ignored@new.example.com'

        expect(project.unsafe_import_url).to eq('https://user@new.example.com')
        expect(project.import_data.password).to be_nil
      end
    end

    context 'when the username is changed' do
      it 'clears the stored password', :aggregate_failures do
        project = build(:project, import_url: 'https://olduser:pass@example.com')
        project.username_only_import_url = 'https://newuser@example.com'

        expect(project.unsafe_import_url).to eq('https://newuser@example.com')
        expect(project.import_data.password).to be_nil
      end
    end

    context 'when the username is removed but the destination is unchanged' do
      it 'retains the stored credentials', :aggregate_failures do
        project = build(:project, import_url: 'https://user:pass@example.com/repo.git')
        project.username_only_import_url = 'https://example.com/repo.git'

        expect(project.import_data.user).to eq('user')
        expect(project.import_data.password).to eq('pass')
      end
    end

    context 'when a password is stored without an import URL' do
      it 'clears the stored password when a URL is set', :aggregate_failures do
        project = build(:project)
        project.build_or_assign_import_data(credentials: { user: 'user', password: 'pass' })
        project.username_only_import_url = 'https://attacker.example.com/repo.git'

        expect(project.unsafe_import_url).to eq('https://user@attacker.example.com/repo.git')
        expect(project.import_data.password).to be_nil
      end
    end

    context 'when the URL is changed and a new password is provided' do
      it 'stores the new password', :aggregate_failures do
        project = build(:project, import_url: 'https://olduser:oldpass@old.example.com')
        project.assign_attributes(
          username_only_import_url: 'https://newuser@new.example.com',
          import_data_attributes: { user: 'newuser', password: 'newpass' }
        )

        expect(project.unsafe_import_url).to eq('https://newuser:newpass@new.example.com')
        expect(project.import_data.password).to eq('newpass')
      end
    end

    it 'clears the username if passed the empty string', :aggregate_failures do
      project = build(:project, import_url: 'http://olduser:pass@old.example.com')
      project.username_only_import_url = ''

      expect(project.username_only_import_url).to eq('')
      expect(project.unsafe_import_url).to eq('')
      expect(project.import_data.user).to be_nil
      expect(project.import_data.password).to eq('pass')
    end
  end

  describe '#build_or_assign_import_data' do
    let(:project) { build(:project) }
    let(:credentials) { nil }

    subject { project.build_or_assign_import_data(credentials: credentials) }

    context 'with credentials' do
      let(:user) { 'someuser' }
      let(:credentials) { { user: user } }

      it 'merges the credentials into the ProjectImportData record' do
        expect(subject).to be_instance_of(ProjectImportData)
        expect(subject.user).to eq(user)
      end
    end
  end

  describe '#licensed_features', :saas do
    let(:plan_license) { :free }
    let(:global_license) { create(:license) }
    let(:group) { create(:group) }
    let!(:gitlab_subscription) { create(:gitlab_subscription, plan_license, namespace: group) }
    let(:project) { create(:project, group: group) }

    before do
      allow(License).to receive(:current).and_return(global_license)
      allow(global_license).to receive(:features).and_return(
        [
          :subepics, # Ultimate only
          :epics, # Premium and up
          :push_rules, # Premium and up
          :audit_events, # Bronze and up
          :geo # Global feature, should not be checked at namespace level
        ])
    end

    subject { project.licensed_features }

    context 'when the namespace should be checked' do
      before do
        enable_namespace_license_check!
      end

      context 'when bronze' do
        let(:plan_license) { :bronze }

        it 'filters for bronze features' do
          is_expected.to contain_exactly(:audit_events, :geo, :push_rules)
        end
      end

      context 'when premium' do
        let(:plan_license) { :premium }

        it 'filters for premium features' do
          is_expected.to contain_exactly(:push_rules, :audit_events, :geo, :epics)
        end
      end

      context 'when ultimate' do
        let(:plan_license) { :ultimate }

        it 'filters for ultimate features' do
          is_expected.to contain_exactly(:epics, :push_rules, :audit_events, :geo, :subepics)
        end
      end

      context 'when free plan' do
        let(:plan_license) { :free }

        it 'filters out paid features' do
          is_expected.to contain_exactly(:geo)
        end

        context 'when public project and namespace' do
          let(:group) { create(:group, :public) }
          let!(:gitlab_subscription) { create(:gitlab_subscription, :free, namespace: group) }
          let(:project) { create(:project, :public, group: group) }

          it 'includes all features in global license' do
            is_expected.to contain_exactly(:epics, :push_rules, :audit_events, :geo, :subepics)
          end
        end

        context 'when service ping features are disabled' do
          before do
            stub_application_setting(usage_ping_features_enabled: false)
          end

          it "doesn't include coverage_fuzzing" do
            is_expected.not_to include(:coverage_fuzzing)
          end
        end

        context 'when service ping features are enabled' do
          before do
            stub_application_setting(usage_ping_features_enabled: true)
          end

          it 'includes coverage_fuzzing' do
            is_expected.to include(:coverage_fuzzing)
          end
        end
      end
    end

    context 'when namespace should not be checked' do
      it 'includes all features in global license' do
        is_expected.to contain_exactly(:epics, :push_rules, :audit_events, :geo, :subepics)
      end
    end

    context 'when there is no license' do
      before do
        allow(License).to receive(:current).and_return(nil)
      end

      it { is_expected.to be_empty }
    end
  end

  describe '#find_path_lock' do
    let_it_be(:project) { create(:project) }
    let_it_be(:path_lock) { create :path_lock, project: project }
    let(:path) { path_lock.path }

    it 'returns path_lock' do
      expect(project.find_path_lock(path)).to eq(path_lock)
    end

    it 'returns nil' do
      expect(project.find_path_lock('app/controllers')).to be_falsey
    end
  end

  describe '#any_path_locks?', :request_store do
    let(:project) { create :project }

    it 'returns false when there are no path locks' do
      expect(project.any_path_locks?).to be_falsey
    end

    it 'returns a cached true when there are path locks' do
      create(:path_lock, project: project)

      expect(project.path_locks).to receive(:any?).once.and_call_original

      2.times { expect(project.any_path_locks?).to be_truthy }
    end
  end

  describe '#has_dependencies?' do
    subject { project.has_dependencies? }

    it 'returns false when project does not have dependencies' do
      is_expected.to be(false)
    end

    it 'returns true when project does have dependencies' do
      create(:sbom_occurrence, project: project)

      is_expected.to be(true)
    end
  end

  describe '#latest_ingested_security_pipeline' do
    let_it_be_with_refind(:project) { create(:project) }
    let_it_be(:pipeline_1) { create(:ee_ci_pipeline, :with_dast_report, :success, project: project) }
    let_it_be(:pipeline_2) { create(:ee_ci_pipeline, project: project) }
    let_it_be(:pipeline_3) { create(:ee_ci_pipeline, :success, project: project) }

    subject { project.latest_ingested_security_pipeline }

    it { is_expected.to eq(pipeline_1) }
  end

  describe '#latest_ingested_sbom_pipeline', :clean_gitlab_redis_shared_state do
    let_it_be(:project) { create(:project) }

    subject { project.latest_ingested_sbom_pipeline }

    context 'when there is no record on Redis' do
      it { is_expected.to be_nil }
    end

    context 'when there is a record on Redis' do
      let(:pipeline) { create(:ee_ci_pipeline, project: project) }

      before do
        project.set_latest_ingested_sbom_pipeline_id(pipeline.id)
      end

      it { is_expected.to eq(pipeline) }
    end
  end

  describe "#latest_pipeline_with_reports_for_ref" do
    let_it_be(:project) { create(:project) }

    context "when pipeline ref is non-default branch" do
      let_it_be(:merge_request) { create(:merge_request, source_project: project) }
      let_it_be(:pipeline_1) { create(:ee_ci_pipeline, :with_sast_report, project: project, ref: merge_request.target_branch) }
      let_it_be(:pipeline_2) { create(:ee_ci_pipeline, :with_sast_report, project: project, ref: merge_request.target_branch) }
      let_it_be(:pipeline_3) { create(:ee_ci_pipeline, :with_dependency_scanning_report, project: project, ref: merge_request.target_branch) }
      let_it_be(:pipeline_4) { create(:ee_ci_pipeline, :with_sast_report, project: project) }

      subject { project.latest_pipeline_with_reports_for_ref(merge_request.target_branch, reports) }

      context 'when reports are found' do
        let(:reports) { ::Ci::JobArtifact.of_report_type(:sast) }

        it "returns the latest pipeline with reports of right type" do
          is_expected.to eq(pipeline_2)
        end

        context 'and one of the pipelines has not yet completed' do
          let_it_be(:pipeline_5) { create(:ee_ci_pipeline, :with_sast_report, project: project, ref: merge_request.target_branch, status: :running) }

          it 'returns the latest successful pipeline with reports' do
            is_expected.to eq(pipeline_2)
          end
        end
      end

      context 'when reports are not found' do
        let(:reports) { ::Ci::JobArtifact.of_report_type(:metrics) }

        it 'returns nothing' do
          is_expected.to be_nil
        end
      end
    end
  end

  describe '#security_reports_up_to_date_for_ref?' do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:merge_request) do
      create(
        :ee_merge_request,
        source_project: project,
        source_branch: 'feature1',
        target_branch: project.default_branch
      )
    end

    let_it_be(:pipeline) do
      create(
        :ee_ci_pipeline,
        :with_sast_report,
        project: project,
        ref: merge_request.target_branch
      )
    end

    subject { project.security_reports_up_to_date_for_ref?(merge_request.target_branch) }

    context 'when the target branch security reports are up to date' do
      it { is_expected.to be true }
    end

    context 'when the target branch security reports are out of date' do
      let_it_be(:bad_pipeline) { create(:ee_ci_pipeline, :failed, project: project, ref: merge_request.target_branch) }

      it { is_expected.to be false }
    end
  end

  describe '#after_import' do
    let_it_be_with_reload(:project) { create(:project) }

    context 'elasticsearch indexing' do
      let_it_be(:import_state) { create(:import_state, project: project) }

      context 'elasticsearch indexing disabled for this project' do
        before do
          expect(project).to receive(:use_elasticsearch?).and_return(false)
        end

        it 'does not index the wiki repository' do
          expect(ElasticWikiIndexerWorker).not_to receive(:perform_async)

          project.after_import
        end
      end

      context 'elasticsearch indexing enabled for this project' do
        before do
          expect(project).to receive(:use_elasticsearch?).and_return(true)
        end

        it 'schedules a full index of the wiki repository using ElasticWikiIndexerWorker' do
          expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(project.id, project.class.name)

          project.after_import
        end

        context 'when project is forked' do
          before do
            expect(project).to receive(:forked?).and_return(true)
          end

          it 'does not index the wiki repository' do
            expect(ElasticWikiIndexerWorker).not_to receive(:perform_async)

            project.after_import
          end
        end
      end
    end

    context 'foundational flows sync' do
      let_it_be(:group) { create(:group) }
      let_it_be(:user) { create(:user) }
      let_it_be_with_reload(:project) { create(:project, group: group, creator: user) }
      let_it_be(:import_state) { create(:import_state, project: project) }

      before do
        allow(project).to receive(:use_elasticsearch?).and_return(false)
      end

      context 'when project does not belong to a group' do
        let_it_be_with_reload(:project) { create(:project, namespace: create(:user).namespace) }

        it 'does not enqueue foundational flows sync worker' do
          expect(Ai::Catalog::Flows::SyncProjectFoundationalFlowsWorker).not_to receive(:perform_async)

          project.after_import
        end
      end

      context 'when duo_foundational_flows_enabled is false' do
        before do
          allow(project).to receive(:duo_foundational_flows_enabled).and_return(false)
        end

        it 'does not enqueue foundational flows sync worker' do
          expect(Ai::Catalog::Flows::SyncProjectFoundationalFlowsWorker).not_to receive(:perform_async)

          project.after_import
        end
      end

      context 'when duo_foundational_flows_enabled is true' do
        before do
          allow(project).to receive(:duo_foundational_flows_enabled).and_return(true)
        end

        it 'enqueues SyncProjectFoundationalFlowsWorker' do
          expect(Ai::Catalog::Flows::SyncProjectFoundationalFlowsWorker)
            .to receive(:perform_async).with(project.id, project.creator.id)

          project.after_import
        end
      end
    end
  end

  describe '#sync_foundational_flows_after_import' do
    let_it_be(:group) { create(:group) }
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, group: group, creator: user) }

    context 'when project has no group' do
      let_it_be(:project) { create(:project, namespace: create(:user).namespace, creator: user) }

      it 'does not enqueue worker' do
        expect(Ai::Catalog::Flows::SyncProjectFoundationalFlowsWorker).not_to receive(:perform_async)

        project.sync_foundational_flows_after_import
      end
    end

    context 'when duo_foundational_flows_enabled is false' do
      before do
        allow(project).to receive(:duo_foundational_flows_enabled).and_return(false)
      end

      it 'does not enqueue worker' do
        expect(Ai::Catalog::Flows::SyncProjectFoundationalFlowsWorker).not_to receive(:perform_async)

        project.sync_foundational_flows_after_import
      end
    end

    context 'when duo_foundational_flows_enabled is true' do
      before do
        allow(project).to receive(:duo_foundational_flows_enabled).and_return(true)
      end

      it 'enqueues SyncProjectFoundationalFlowsWorker with project id and creator id' do
        expect(Ai::Catalog::Flows::SyncProjectFoundationalFlowsWorker)
          .to receive(:perform_async).with(project.id, user.id)

        project.sync_foundational_flows_after_import
      end

      context 'when creator is nil' do
        before do
          allow(project).to receive(:creator).and_return(nil)
        end

        it 'enqueues worker with nil user_id' do
          expect(Ai::Catalog::Flows::SyncProjectFoundationalFlowsWorker)
            .to receive(:perform_async).with(project.id, nil)

          project.sync_foundational_flows_after_import
        end
      end
    end
  end

  describe '#use_zoekt?', feature_category: :global_search do
    let_it_be(:project) { create(:project, :public) }

    it 'delegates to ::Search::Zoekt.index?' do
      expect(::Search::Zoekt).to receive(:index?).with(project).and_return(true)

      expect(project.use_zoekt?).to be(true)
    end
  end

  describe '#knowledge_graph_indexing_enabled?', feature_category: :knowledge_graph do
    let_it_be(:project) { create(:project) }

    context 'when the root namespace has knowledge graph enabled' do
      before do
        create(:knowledge_graph_enabled_namespace, namespace: project.root_ancestor)
      end

      it 'returns true' do
        expect(project.knowledge_graph_indexing_enabled?).to be(true)
      end
    end

    context 'when the root namespace does not have knowledge graph enabled' do
      it 'returns false' do
        expect(project.knowledge_graph_indexing_enabled?).to be(false)
      end
    end
  end

  describe '#lfs_http_url_to_repo' do
    let_it_be(:project) { create(:project) }
    let(:project_path) { "#{Gitlab::Routing.url_helpers.project_path(project)}.git" }

    let(:primary_base_host) { 'primary.geo' }
    let(:primary_base_url) { "http://#{primary_base_host}" }
    let(:primary_url) { "#{primary_base_url}#{project_path}" }

    context 'with a Geo setup that is a primary' do
      let(:primary_node) { create(:geo_node, url: primary_base_url) }

      before do
        stub_current_geo_node(primary_node)
        stub_default_url_options(primary_base_host)
      end

      context 'for an upload operation' do
        it 'returns the project HTTP URL for the primary' do
          expect(project.lfs_http_url_to_repo('upload')).to eq(primary_url)
        end
      end
    end

    context 'with a Geo setup that is a secondary' do
      let(:secondary_base_host) { 'secondary.geo' }
      let(:secondary_base_url) { "http://#{secondary_base_host}" }
      let(:secondary_node) { create(:geo_node, url: secondary_base_url) }
      let(:secondary_url) { "#{secondary_base_url}#{project_path}" }

      before do
        stub_current_geo_node(secondary_node)
        stub_default_url_options(current_rails_hostname)
      end

      context 'and has a primary' do
        let(:primary_node) { create(:geo_node, url: primary_base_url) }

        context 'for an upload operation' do
          let(:current_rails_hostname) { primary_base_host }

          it 'returns the project HTTP URL for the primary' do
            expect(project.lfs_http_url_to_repo('upload')).to eq(primary_url)
          end
        end

        context 'for a download operation' do
          let(:current_rails_hostname) { secondary_base_host }

          it 'returns the project HTTP URL for the secondary' do
            expect(project.lfs_http_url_to_repo('download')).to eq(secondary_url)
          end
        end
      end

      context 'without a primary' do
        let(:current_rails_hostname) { secondary_base_host }

        it 'returns the project HTTP URL for the secondary' do
          expect(project.lfs_http_url_to_repo('operation_that_doesnt_matter')).to eq(secondary_url)
        end
      end
    end

    context 'without a Geo setup' do
      it 'returns the project HTTP URL for the main node' do
        project_url = "#{Gitlab::Routing.url_helpers.project_url(project)}.git"

        expect(project.lfs_http_url_to_repo('operation_that_doesnt_matter')).to eq(project_url)
      end
    end
  end

  describe 'import_state creation for transfer imports that become mirrors' do
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:project) { create(:project, :repository) }

    before do
      stub_licensed_features(repository_mirrors: true)
    end

    %w[gitlab_project_migration offline_transfer].each do |type|
      context "when a #{type} project enables mirroring" do
        before do
          project.update!(import_type: type)
        end

        it 'creates the import_state the mirror needs' do
          expect(project.import_state).to be_nil

          project.update!(mirror: true, import_url: 'http://some_url.com', mirror_user_id: user.id)

          expect(project.reload.import_state).to be_present
        end
      end
    end
  end

  describe '#add_import_job' do
    let_it_be(:user) { create(:user) }
    let_it_be(:mirroring_params) { { mirror: true, import_url: 'http://some_url.com', mirror_user_id: user.id } }

    before do
      stub_licensed_features(custom_project_templates: true)
    end

    context 'when import_type is gitlab_custom_project_template' do
      let(:project) { build(:project, import_type: 'gitlab_custom_project_template') }

      context 'when repository does not exist' do
        it 'does not create import job' do
          expect(project.add_import_job).to be_nil
        end

        context 'when mirroring is enabled' do
          before do
            project.update!(mirroring_params)
          end

          it 'does not create import job' do
            expect(project.add_import_job).to be_nil
          end
        end
      end

      context 'when repository exists' do
        before do
          allow(project.repository).to receive(:exists?).and_return(true)
        end

        it 'does not create import job' do
          expect(project.add_import_job).to be_nil
        end

        context 'when mirroring is enabled' do
          before do
            project.update!(mirroring_params)
          end

          it 'schedules an import job' do
            expect(project.add_import_job).to be_present
          end
        end
      end
    end

    context 'when mirror true on a jira imported project' do
      let_it_be(:project) { create(:project, :repository, import_type: 'jira', mirror: true, import_url: 'http://some_url.com', mirror_user_id: user.id) }
      let_it_be(:jira_import) { create(:jira_import_state, project: project) }

      context 'when jira import is in progress' do
        before do
          jira_import.start
        end

        it 'triggers mirror update' do
          expect(RepositoryUpdateMirrorWorker).to receive(:perform_async)
          expect(Gitlab::JiraImport::Stage::StartImportWorker).not_to receive(:perform_async)
          expect(project.mirror).to be true
          expect(project.jira_import?).to be true

          project.add_import_job
        end
      end
    end

    context 'when an existing mirror reports its repository as missing at scheduling time' do
      let(:project) do
        create(:project, :repository, import_type: 'github').tap do |project|
          project.update!(mirroring_params)
        end
      end

      before do
        stub_licensed_features(custom_project_templates: true, repository_mirrors: true)

        # Simulate a transient Gitaly existence miss. Its negative result is never
        # cached, so a blip at scheduling time would otherwise force a full import.
        allow(project.repository).to receive(:exists?).and_return(false)
      end

      context 'when the mirror has never completed a successful update' do
        it 'schedules a full import via RepositoryImportWorker', :aggregate_failures do
          expect(RepositoryImportWorker).to receive(:perform_async).with(project.id)
          expect(RepositoryUpdateMirrorWorker).not_to receive(:perform_async)

          project.add_import_job
        end
      end

      context 'when the mirror has completed a successful update before' do
        before do
          project.import_state.update!(
            last_update_at: Time.current,
            last_successful_update_at: Time.current
          )
        end

        it 'schedules a mirror update instead of a full re-import', :aggregate_failures do
          expect(RepositoryUpdateMirrorWorker).to receive(:perform_async).with(project.id)
          expect(RepositoryImportWorker).not_to receive(:perform_async)

          project.add_import_job
        end
      end
    end
  end

  describe '#gitlab_custom_project_template_import?' do
    let_it_be(:project) { create(:project, import_type: 'gitlab_custom_project_template') }

    context 'when licensed' do
      before do
        stub_licensed_features(custom_project_templates: true)
      end

      it 'returns true' do
        expect(project.gitlab_custom_project_template_import?).to be true
      end
    end

    context 'when unlicensed' do
      it 'returns false' do
        expect(project.gitlab_custom_project_template_import?).to be false
      end
    end
  end

  describe '#notify_project_import_complete?' do
    let(:project) { build(:project, import_type: 'gitlab_custom_project_template') }

    it 'returns false for gitlab_custom_project_template import type' do
      expect(project.notify_project_import_complete?).to be(false)
    end
  end

  describe '#feature_flags_client_token' do
    let(:project) { create(:project) }

    subject { project.feature_flags_client_token }

    context 'when there is no access token' do
      it "creates a new one" do
        is_expected.not_to be_empty
      end
    end

    context 'when there is access token' do
      let(:token_encrypted) { Gitlab::CryptoHelper.aes256_gcm_encrypt('token') }
      let!(:instance) { create(:operations_feature_flags_client, project: project, token_encrypted: token_encrypted) }

      it "provides an existing one" do
        is_expected.to eq('token')
      end
    end
  end

  describe '#has_pool_repository?' do
    it 'returns false when there is no pool repository' do
      project = create(:project)

      expect(project.has_pool_repository?).to be false
    end

    it 'returns true when there is a pool repository' do
      pool = create(:pool_repository, :ready)
      project = create(:project, pool_repository: pool)

      expect(project.has_pool_repository?).to be true
    end
  end

  describe '#link_pool_repository' do
    let(:project) { create(:project, :repository) }

    subject  { project.link_pool_repository }

    it 'logs geo event' do
      expect(project.repository).to receive(:log_geo_updated_event)

      subject
    end
  end

  describe '#elastic_namespace_ancestry' do
    let_it_be(:project) { create(:project) }

    it 'is a combination of the namespace and project id' do
      expect(project.elastic_namespace_ancestry).to eq("#{project.namespace.id}-p#{project.id}-")
    end
  end

  describe '#object_pool_missing?' do
    let(:pool) { create(:pool_repository, :ready) }

    subject { create(:project, :repository, pool_repository: pool) }

    it 'returns true when object pool is missing' do
      allow(pool.object_pool).to receive(:exists?).and_return(false)

      expect(subject.object_pool_missing?).to be true
    end

    it "returns false when pool repository doesnt't exist" do
      allow(subject).to receive(:has_pool_repository?).and_return(false)

      expect(subject.object_pool_missing?).to be false
    end

    it 'returns false when object pool exists' do
      expect(subject.object_pool_missing?).to be false
    end
  end

  describe "#insights_config" do
    context 'when project has no Insights config file' do
      let(:project) { create(:project) }

      it 'returns the project default config' do
        expect(project.insights_config).to eq(project.default_insights_config)
      end

      context 'when the project is inside a group' do
        let(:group) { create(:group) }
        let(:project) { create(:project, group: group) }

        context 'when the group has no Insights config' do
          it 'returns the group default config' do
            expect(project.insights_config).to eq(group.default_insights_config)
          end
        end

        context 'when the group has an Insights config from another project' do
          let(:config_project) do
            create(:project, :custom_repo, group: group, files: { ::Gitlab::Insights::CONFIG_FILE_PATH => insights_file_content })
          end

          before do
            group.create_insight!(project: config_project)
          end

          context 'with a valid config file' do
            let(:insights_file_content) { 'key: monthlyBugsCreated' }

            it 'returns the group config data from the other project' do
              expect(project.insights_config).to eq(config_project.insights_config)
              expect(project.insights_config).to eq(group.insights_config)
            end

            context 'when the project is inside a nested group' do
              let(:nested_group) { create(:group, parent: group) }
              let(:project) { create(:project, group: nested_group) }

              # The following expectaction should be changed to
              # expect(project.insights_config).to eq(config_project.insights_config)
              # once https://gitlab.com/gitlab-org/gitlab/issues/11340 is implemented.
              it 'returns the project default config' do
                expect(project.insights_config).to eq(project.default_insights_config)
              end
            end
          end

          context 'with an invalid config file' do
            let(:insights_file_content) { ': foo bar' }

            it 'returns nil' do
              expect(project.insights_config).to be_nil
            end
          end
        end
      end
    end

    context 'when project has an Insights config file' do
      let(:project) do
        create(:project, :custom_repo, files: { ::Gitlab::Insights::CONFIG_FILE_PATH => insights_file_content })
      end

      context 'with a valid config file' do
        let(:insights_file_content) { "monthlyBugsCreated:\n  title: My chart" }

        it 'returns the insights config data' do
          expect(project.insights_config).to eq(monthlyBugsCreated: { title: 'My chart' })
        end

        context 'when the project is inside a group having another config' do
          let(:group) { create(:group) }
          let(:config_project) do
            create(:project, :custom_repo, group: group, files: { ::Gitlab::Insights::CONFIG_FILE_PATH => ': foo bar' })
          end

          before do
            project.group = group
            project.group.create_insight!(project: config_project)
          end

          it 'returns the project insights config data' do
            expect(project.insights_config).to eq(monthlyBugsCreated: { title: 'My chart' })
          end
        end
      end

      context 'with a structurally invalid config file' do
        let(:insights_file_content) { 'top_level_string: just_a_string' }

        it 'returns only valid entries and reports config as invalid' do
          expect(project.insights_config).to eq({})
          expect(project.insights_config_valid?).to be(false)
        end
      end

      context 'with a partially valid config file' do
        let(:insights_file_content) { "good:\n  title: Good\nbad: just_a_string" }

        it 'returns only the valid entries and reports config as invalid' do
          expect(project.insights_config).to eq(good: { title: 'Good' })
          expect(project.insights_config_valid?).to be(false)
        end
      end

      context 'with a YAML-anchor entry alongside a renderable entry' do
        let(:insights_file_content) do
          <<~YAML
            .projectsOnly:
              projects:
                only:
                  - 1
            good:
              title: Good
          YAML
        end

        it 'filters the anchor out without flagging the config as invalid' do
          expect(project.insights_config).to eq(good: { title: 'Good' })
          expect(project.insights_config_valid?).to be(true)
        end
      end

      context 'with an invalid config file' do
        let(:insights_file_content) { ': foo bar' }

        it 'returns nil' do
          expect(project.insights_config).to be_nil
        end

        context 'when the project is inside a group having another config' do
          let(:group) { create(:group) }
          let(:config_project) do
            create(:project, :custom_repo, group: group, files: { ::Gitlab::Insights::CONFIG_FILE_PATH => 'key: monthlyBugsCreated' })
          end

          before do
            project.group = group
            project.group.create_insight!(project: config_project)
          end

          it 'returns nil' do
            expect(project.insights_config).to be_nil
          end
        end
      end
    end
  end

  describe "#kerberos_url_to_repo" do
    let(:project) { create(:project, path: "somewhere") }

    it 'returns valid kerberos url for this repo' do
      expect(project.kerberos_url_to_repo).to eq("#{Gitlab.config.build_gitlab_kerberos_url}/#{project.namespace.path}/somewhere.git")
    end
  end

  describe '#actual_repository_size_limit' do
    context 'when repository_size_limit is set on the project' do
      it 'returns the repository_size_limit' do
        project = build(:project, repository_size_limit: 10)

        expect(project.actual_repository_size_limit).to eq(10)
      end
    end

    context 'when repository_size_limit is not set on the project' do
      it 'returns the actual_repository_size_limit of the namespace' do
        group = build(:group, repository_size_limit: 20)
        project = build(:project, namespace: group, repository_size_limit: nil)

        expect(project.actual_repository_size_limit).to eq(20)
      end
    end
  end

  describe '#repository_size_checker' do
    let(:project) { build(:project) }
    let(:checker) { project.repository_size_checker }

    describe '#current_size' do
      let(:project) { create(:project) }

      it 'returns the total repository and lfs size' do
        allow(project.statistics).to receive(:total_repository_size).and_return(80)

        expect(checker.current_size).to eq(80)
      end
    end

    describe '#limit' do
      it 'returns the value set in the namespace when available' do
        allow(project.namespace).to receive(:actual_repository_size_limit).and_return(100)

        expect(checker.limit).to eq(100)
      end

      it 'returns the value set locally when available' do
        project.repository_size_limit = 200

        expect(checker.limit).to eq(200)
      end
    end

    describe '#enabled?' do
      it 'returns true when not equal to zero' do
        project.repository_size_limit = 1

        expect(checker.enabled?).to be_truthy
      end

      it 'returns false when equals to zero' do
        project.repository_size_limit = 0

        expect(checker.enabled?).to be_falsey
      end

      context 'when repository_size_limit is configured' do
        before do
          project.repository_size_limit = 1
        end

        context 'when license feature enabled' do
          before do
            stub_licensed_features(repository_size_limit: true)
          end

          it 'size limit is enabled' do
            expect(checker.enabled?).to be_truthy
          end
        end

        context 'when license feature disabled' do
          before do
            stub_licensed_features(repository_size_limit: false)
          end

          it 'size limit is disabled' do
            expect(checker.enabled?).to be_falsey
          end
        end

        context 'when usage ping is enabled' do
          before do
            allow(License).to receive(:current).and_return(nil)
            stub_application_setting(usage_ping_enabled: true)
          end

          context 'when usage_ping_features is activated' do
            before do
              stub_application_setting(usage_ping_features_enabled: true)
            end

            it 'size limit is enabled' do
              expect(checker.enabled?).to be_truthy
            end
          end

          context 'when usage_ping_features is disabled' do
            before do
              stub_application_setting(usage_ping_features_enabled: false)
            end

            it 'size limit is disabled' do
              expect(checker.enabled?).to be_falsy
            end
          end
        end

        context 'when usage ping is disabled' do
          before do
            stub_licensed_features(repository_size_limit: false)
            stub_application_setting(usage_ping_enabled: false)
          end

          it 'size limit is disabled' do
            expect(checker.enabled?).to be_falsey
          end
        end
      end
    end
  end

  describe '#repository_size_excess' do
    subject { project.repository_size_excess }

    let_it_be(:statistics) { create(:project_statistics) }
    let_it_be(:project) { statistics.project }

    where(:total_repository_size, :size_limit, :result) do
      50 | nil | 0
      50 | 0   | 0
      50 | 60  | 0
      50 | 50  | 0
      50 | 10  | 40
    end

    with_them do
      before do
        allow(project).to receive(:actual_repository_size_limit).and_return(size_limit)
        allow(statistics).to receive(:total_repository_size).and_return(total_repository_size)
      end

      it { is_expected.to eq(result) }
    end
  end

  describe '#repository_size_limit column' do
    it 'support values up to 8 exabytes' do
      project = create(:project)
      project.update_column(:repository_size_limit, 8.exabytes - 1)

      project.reload

      expect(project.repository_size_limit).to eql(8.exabytes - 1)
    end
  end

  describe 'handling import URL' do
    context 'when project is a mirror' do
      it 'returns the full URL' do
        project = create(:project, :mirror, import_url: 'http://user:pass@test.com')

        project.import_state.finish

        expect(project.reload.unsafe_import_url).to eq('http://user:pass@test.com')
      end
    end

    context 'project is inside a fork network' do
      subject { project }

      let(:project) { create(:project, fork_network: fork_network) }
      let(:fork_network) { create(:fork_network) }

      before do
        stub_config_setting(host: 'gitlab.com')
      end

      context 'the project is the root of the fork network' do
        before do
          project.import_url = "https://customgitlab.com/foo/bar.git"
          expect(fork_network).to receive(:root_project).and_return(project)
        end

        it { is_expected.to be_valid }
      end

      context 'the URL is inside the fork network' do
        before do
          project.import_url = "https://#{Gitlab.config.gitlab.host}/#{project.fork_network.root_project.full_path}.git"
        end

        it { is_expected.to be_valid }
      end

      context 'the URL is external but the project exists' do
        it 'raises an error' do
          project.import_url = "https://customgitlab.com/#{project.fork_network.root_project.full_path}.git"
          project.validate

          expect(project.errors[:url]).to include('must be inside the fork network')
        end
      end

      context 'the URL is not inside the fork network' do
        it 'raises an error' do
          project.import_url = "https://customgitlab.com/foo/bar.git"
          project.validate

          expect(project.errors[:url]).to include('must be inside the fork network')
        end
      end
    end
  end

  describe '#add_import_job' do
    let(:import_jid) { '123' }

    context 'forked' do
      let(:forked_from_project) { create(:project, :repository) }
      let(:project) { create(:project) }

      before do
        fork_project(forked_from_project, nil, target_project: project)
      end

      context 'without mirror' do
        it 'returns nil' do
          project = create(:project)

          expect(project.add_import_job).to be_nil
        end
      end

      context 'with mirror' do
        it 'schedules RepositoryUpdateMirrorWorker' do
          project = create(:project, :mirror, :repository)

          expect(RepositoryUpdateMirrorWorker).to receive(:perform_async).with(project.id).and_return(import_jid)
          expect(project.add_import_job).to eq(import_jid)
        end
      end
    end
  end

  describe '.where_full_path_in' do
    context 'without any paths' do
      it 'returns an empty relation' do
        expect(described_class.where_full_path_in([])).to eq([])
      end
    end

    context 'without any valid paths' do
      it 'returns an empty relation' do
        expect(described_class.where_full_path_in(%w[foo])).to eq([])
      end
    end

    context 'with valid paths' do
      let_it_be(:project1) { create(:project) }
      let_it_be(:project2) { create(:project) }

      it 'returns the projects matching the paths' do
        projects = described_class.where_full_path_in([project1.full_path,
          project2.full_path])

        expect(projects).to contain_exactly(project1, project2)
      end

      it 'returns projects regardless of the casing of paths' do
        projects = described_class.where_full_path_in([project1.full_path.upcase,
          project2.full_path.upcase])

        expect(projects).to contain_exactly(project1, project2)
      end
    end
  end

  describe '#create_import_state' do
    it 'is called after save' do
      project = create(:project)

      expect(project).to receive(:create_import_state)

      project.update!(mirror: true, mirror_user: project.first_owner, import_url: 'http://foo.com')
    end
  end

  describe '#allowed_to_share_with_group?' do
    context 'for group related project' do
      subject(:project) { build_stubbed(:project, namespace: group, group: group) }

      let(:group) { build_stubbed :group }

      context 'with lock_memberships_to_ldap application setting enabled' do
        before do
          stub_application_setting(lock_memberships_to_ldap: true)
        end

        it { is_expected.not_to be_allowed_to_share_with_group }
      end

      context 'with lock_memberships_to_saml group setting enabled' do
        let(:group) { build_stubbed(:group) }

        before do
          stub_application_setting(lock_memberships_to_saml: true)
        end

        context 'with lock for ldap membership disabled' do
          it { is_expected.not_to be_allowed_to_share_with_group }
        end

        context 'with lock for ldap membership enabled' do
          before do
            stub_application_setting(lock_memberships_to_ldap: true)
          end

          it { is_expected.not_to be_allowed_to_share_with_group }
        end
      end

      context 'with lock_memberships_to_saml group setting disabled' do
        let(:group) { build_stubbed(:group) }

        before do
          stub_application_setting(lock_memberships_to_saml: false)
        end

        context 'with lock for ldap membership disabled' do
          it { is_expected.to be_allowed_to_share_with_group }
        end

        context 'with lock for ldap membership enabled' do
          before do
            stub_application_setting(lock_memberships_to_ldap: true)
          end

          it { is_expected.not_to be_allowed_to_share_with_group }
        end
      end
    end

    context 'personal project' do
      subject(:project) { build_stubbed(:project, namespace: namespace) }

      let(:namespace) { build_stubbed :namespace }

      context 'with lock_memberships_to_ldap application setting enabled' do
        before do
          stub_application_setting(lock_memberships_to_ldap: true)
        end

        it { is_expected.to be_allowed_to_share_with_group }
      end
    end
  end

  # Despite stubbing the current node as the primary or secondary, the
  # behaviour for EE::Project#lfs_http_url_to_repo() is to call
  # Project#lfs_http_url_to_repo() which does not have a Geo context.
  def stub_default_url_options(host)
    allow(Rails.application.routes)
      .to receive(:default_url_options)
      .and_return(host: host)
  end

  describe 'calculate template repositories' do
    let_it_be(:group1) { create(:group) }
    let_it_be_with_reload(:group2) { create(:group) }
    let_it_be(:group2_sub1) { create(:group, parent: group2) }
    let_it_be(:group2_sub2) { create(:group, parent: group2) }

    before_all do
      group2.update!(custom_project_templates_group_id: group2_sub2.id)
      create(:project, group: group1)
      create_list(:project, 2, group: group2)
      create_list(:project, 3, group: group2_sub1)
      create_list(:project, 4, group: group2_sub2)
    end

    before do
      stub_ee_application_setting(custom_project_templates_group_id: group2.id)
    end

    it 'counts instance level templates' do
      expect(described_class.with_repos_templates.count).to eq(2)
    end

    it 'counts group level templates' do
      expect(described_class.with_groups_level_repos_templates.count).to eq(4)
    end
  end

  describe '#license_compliance' do
    it { expect(subject.license_compliance).to be_instance_of(::SCA::LicenseCompliance) }

    context 'when pipeline is nil' do
      it 'passes nil as target_branch' do
        allow(::Gitlab::LicenseScanning.scanner_for_project(subject)).to receive(:pipeline).and_return(nil)

        expect(::SCA::LicenseCompliance).to receive(:new).with(subject, nil, nil)
        subject.license_compliance
      end
    end

    context 'when pipeline is present' do
      let_it_be(:project) { create(:project) }
      let_it_be(:pipeline) { create(:ci_pipeline, project: project, ref: 'main') }

      subject(:license_compliance) { project.license_compliance(pipeline) }

      context 'when pipeline has no associated merge requests' do
        it 'passes the pipeline ref as target_branch' do
          expect(::SCA::LicenseCompliance).to receive(:new).with(project, pipeline, pipeline.ref)

          license_compliance
        end
      end

      context 'when pipeline is a merge request pipeline' do
        let_it_be(:merge_request) { create(:merge_request, target_branch: 'release', source_project: project) }
        let_it_be(:pipeline) { create(:ci_pipeline, project: project, merge_request_id: merge_request.id) }

        it 'uses the merge request target branch' do
          expect(::SCA::LicenseCompliance).to receive(:new).with(project, pipeline, merge_request.target_branch)

          license_compliance
        end
      end

      context 'when pipeline is a branch pipeline with an associated merge request' do
        let_it_be(:merge_request) do
          create(:merge_request, target_branch: 'main', source_branch: 'feature', source_project: project)
        end

        let_it_be(:pipeline) do
          create(:ci_pipeline, project: project, ref: merge_request.source_branch)
        end

        before do
          allow(pipeline).to receive(:all_merge_requests_by_recency).and_return([merge_request])
        end

        it 'uses the most recent associated merge request target branch' do
          expect(::SCA::LicenseCompliance).to receive(:new).with(project, pipeline, merge_request.target_branch)

          license_compliance
        end

        context 'when multiple merge requests are associated' do
          let_it_be(:older_merge_request) do
            create(:merge_request, target_branch: 'stable', source_branch: 'feature', source_project: project)
          end

          before do
            allow(pipeline).to receive(:all_merge_requests_by_recency).and_return([merge_request, older_merge_request])
          end

          it 'uses the most recently created merge request target branch' do
            expect(::SCA::LicenseCompliance).to receive(:new).with(project, pipeline, merge_request.target_branch)

            license_compliance
          end
        end
      end
    end
  end

  describe '#template_source?' do
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:subgroup) { create(:group, :private, parent: group) }
    let_it_be(:project_template) { create(:project, group: subgroup) }

    context 'when project is not template source' do
      it 'returns false' do
        expect(project.template_source?).to be_falsey
      end
    end

    context 'instance-level custom project templates' do
      before do
        stub_ee_application_setting(custom_project_templates_group_id: subgroup.id)
      end

      it 'returns true' do
        expect(project_template.template_source?).to be_truthy
      end
    end

    context 'group-level custom project templates' do
      before do
        group.update!(custom_project_templates_group_id: subgroup.id)
      end

      it 'returns true' do
        expect(project_template.template_source?).to be_truthy
      end
    end
  end

  describe '#remove_import_data' do
    let(:import_data) { ProjectImportData.new(data: { 'test' => 'some data' }) }

    context 'when mirror' do
      let(:user) { create(:user) }
      let!(:project) { create(:project, mirror: true, import_url: 'http://some_url.com', mirror_user_id: user.id, import_data: import_data) }

      it 'does not remove import data' do
        expect(project.mirror?).to be true
        expect(project.jira_import?).to be false
        expect { project.remove_import_data }.not_to change { ProjectImportData.count }
      end
    end
  end

  describe '#add_template_export_job' do
    it 'starts project template export job' do
      user = create(:user)
      project = build(:project)

      expect(ProjectTemplateExportWorker).to receive(:perform_async).with(user.id, project.id, nil, {})

      project.add_template_export_job(current_user: user)
    end
  end

  describe '#prevent_merge_without_jira_issue?' do
    subject { project.prevent_merge_without_jira_issue? }

    where(:feature_available, :prevent_merge, :result) do
      true  | true  | true
      true  | false | false
      false | true  | false
      false | false | false
    end

    with_them do
      before do
        allow(project).to receive(:jira_issue_association_required_to_merge_enabled?).and_return(feature_available)
        project.create_project_setting(prevent_merge_without_jira_issue: prevent_merge)
      end

      it { is_expected.to be result }
    end
  end

  context 'indexing updates in Elasticsearch', :elastic do
    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    context 'on update' do
      let(:project) { create(:project, :public) }
      let!(:issue) { create(:issue, project: project) }
      let!(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

      context 'when updating the visibility_level' do
        it 'triggers ElasticAssociationIndexerWorker to update associations' do
          expect(ElasticAssociationIndexerWorker).to receive(:perform_async)
            .with('Project', project.id, %w[issues work_items merge_requests notes milestones])

          project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
        end

        it 'ensures all visibility_level updates are correctly applied in merge_request searches', :sidekiq_inline do
          ensure_elasticsearch_index!
          results = MergeRequest.elastic_search('*', options: { search_level: 'global', public_and_internal_projects: true })
          expect(results.count).to eq(1)

          project.update!(visibility_level: Gitlab::VisibilityLevel::INTERNAL)
          ensure_elasticsearch_index!

          results = MergeRequest.elastic_search('*', options: { search_level: 'global', public_and_internal_projects: true })
          expect(results.count).to eq(0)
        end
      end

      context 'when changing the title' do
        it 'does not trigger ElasticAssociationIndexerWorker to update issues' do
          expect(ElasticAssociationIndexerWorker).not_to receive(:perform_async)

          project.update!(title: 'The new title')
        end
      end
    end
  end

  describe '#available_shared_runners' do
    let_it_be(:runner) { create(:ci_runner, :instance) }

    let(:project) { build_stubbed(:project, shared_runners_enabled: true) }

    subject { project.available_shared_runners }

    before do
      allow(project).to receive(:ci_minutes_usage)
        .and_return(double('quota', minutes_used_up?: minutes_used_up))
    end

    context 'when compute minutes are available for project' do
      let(:minutes_used_up) { false }

      it 'returns a list of shared runners' do
        is_expected.to eq([runner])
      end
    end

    context 'when out of compute minutes for project' do
      let(:minutes_used_up) { true }

      it 'returns a empty list' do
        is_expected.to be_empty
      end
    end
  end

  describe '#all_available_runners' do
    let_it_be_with_refind(:project) do
      create(:project, group: create(:group), shared_runners_enabled: true)
    end

    let_it_be(:instance_runner) { create(:ci_runner, :instance) }
    let_it_be(:group_runner) { create(:ci_runner, :group, groups: [project.group]) }
    let_it_be(:project_runner) { create(:ci_runner, :project, projects: [project]) }

    subject { project.all_available_runners }

    before do
      allow(project).to receive(:ci_minutes_usage)
        .and_return(double('quota', minutes_used_up?: minutes_used_up))
    end

    context 'when compute minutes are available for project' do
      let(:minutes_used_up) { false }

      it 'returns a list with all runners' do
        is_expected.to match_array([instance_runner, group_runner, project_runner])
      end
    end

    context 'when out of compute minutes for project' do
      let(:minutes_used_up) { true }

      it 'returns a list with non-instance runners' do
        is_expected.to match_array([group_runner, project_runner])
      end
    end
  end

  describe '#upstream_projects' do
    it 'returns the upstream projects' do
      upstream_project = create(:project, :public)
      primary_project = create(:project, :public, upstream_projects: [upstream_project])

      with_cross_joins_prevented do
        expect(primary_project.upstream_projects).to eq([upstream_project])
      end
    end
  end

  describe '#upstream_projects_count' do
    it 'returns the upstream projects count' do
      upstream_projects = create_list(:project, 2, :public)
      primary_project = create(:project, :public, upstream_projects: upstream_projects)

      with_cross_joins_prevented do
        expect(primary_project.upstream_projects_count).to eq(2)
      end
    end
  end

  describe '#ci_cancellation_restriction' do
    it 'returns the initialized cancellation restriction object' do
      expect(project.ci_cancellation_restriction.class).to be Ci::ProjectCancellationRestriction
      expect(project.ci_cancellation_restriction).to respond_to(:feature_available?)
    end
  end

  describe '#visible_approval_rules' do
    let!(:scan_finding_rule) { create(:approval_project_rule, :scan_finding, project: project) }
    let!(:license_scanning_rule) { create(:approval_project_rule, :license_scanning, project: project) }
    let!(:any_merge_request_rule) { create(:approval_project_rule, :any_merge_request, project: project) }

    subject { project.visible_approval_rules }

    it { is_expected.not_to include(scan_finding_rule, license_scanning_rule, any_merge_request_rule) }
  end

  describe '#affected_by_security_policy_management_project?' do
    subject { project.affected_by_security_policy_management_project?(security_policy_management_project) }

    let_it_be(:spp_project) { create(:project, :repository) }
    let_it_be(:other_spp_project) { create(:project, :repository) }

    let(:security_policy_management_project) { spp_project }

    it { is_expected.to be(false) }

    context 'when security orchestration policy is configured for project' do
      let_it_be(:project) { create(:project) }
      let_it_be(:project_security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration, project: project,
          security_policy_management_project: spp_project)
      end

      it { is_expected.to be(true) }

      context 'with other security policy management project' do
        let(:security_policy_management_project) { other_spp_project }

        it { is_expected.to be(false) }
      end
    end

    context 'when security orchestration policy is configured for a parent namespace' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:child_group) { create(:group, parent: parent_group) }
      let_it_be(:project) { create(:project, group: child_group) }

      let_it_be(:parent_group_security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration, :namespace, namespace: parent_group,
          security_policy_management_project: spp_project)
      end

      it { is_expected.to be(true) }

      context 'with other security policy management project' do
        let(:security_policy_management_project) { other_spp_project }

        it { is_expected.to be(false) }
      end
    end

    context 'when security orchestration policy is configured for another project' do
      let_it_be(:another_project) { create(:project) }
      let_it_be(:project_security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration, project: another_project,
          security_policy_management_project: spp_project)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#designated_as_csp?' do
    subject { project.designated_as_csp? }

    it { is_expected.to be(false) }
  end

  describe '#all_security_orchestration_policy_configurations' do
    subject(:configurations) { project.all_security_orchestration_policy_configurations }

    context 'when security orchestration policy is configured for project only' do
      let!(:project_security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration, project: project)
      end

      context 'when configuration is invalid' do
        before do
          allow(project_security_orchestration_policy_configuration).to receive(:policy_configuration_valid?).and_return(false)
        end

        it { is_expected.to be_empty }

        context 'when including invalid configurations' do
          subject { project.all_security_orchestration_policy_configurations(include_invalid: true) }

          it { is_expected.to contain_exactly(project_security_orchestration_policy_configuration) }
        end
      end

      context 'when configuration is valid' do
        before do
          allow(project_security_orchestration_policy_configuration).to receive(:policy_configuration_valid?).and_return(true)
          allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |configuration|
            allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
          end
        end

        it { is_expected.to contain_exactly(project_security_orchestration_policy_configuration) }

        context 'with a designated CSP group' do
          include_context 'with csp group configuration'

          it 'returns security policy configurations including the CSP configuration' do
            expect(configurations).to contain_exactly(
              csp_security_orchestration_policy_configuration,
              project_security_orchestration_policy_configuration
            )
          end
        end
      end
    end

    context 'when security orchestration policy is configured for namespaces and project' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:child_group) { create(:group, parent: parent_group) }
      let_it_be(:child_group_2) { create(:group, parent: child_group) }
      let_it_be_with_refind(:project) { create(:project, group: child_group_2) }

      let_it_be(:parent_security_orchestration_policy_configuration) { create(:security_orchestration_policy_configuration, :namespace, namespace: parent_group) }
      let_it_be(:child_security_orchestration_policy_configuration) { create(:security_orchestration_policy_configuration, :namespace, namespace: child_group) }
      let_it_be(:child_security_orchestration_policy_configuration_2) { create(:security_orchestration_policy_configuration, :namespace, namespace: child_group_2) }

      let_it_be(:project_security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration, project: project)
      end

      context 'when configuration is invalid' do
        before do
          allow_next_found_instances_of(Security::OrchestrationPolicyConfiguration, 4) do |configuration|
            allow(configuration).to receive(:policy_configuration_valid?).and_return(false)
          end
        end

        it 'returns security policy configurations for all valid parent groups and project' do
          expect(configurations).to be_empty
        end
      end

      context 'when configuration is valid' do
        before do
          allow_next_found_instances_of(Security::OrchestrationPolicyConfiguration, 5) do |configuration|
            allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
          end
        end

        it 'returns security policy configurations for all valid parent groups and project' do
          expect(configurations).to match_array(
            [
              parent_security_orchestration_policy_configuration,
              child_security_orchestration_policy_configuration,
              child_security_orchestration_policy_configuration_2,
              project_security_orchestration_policy_configuration
            ]
          )
        end

        context 'when organization_policy_setting is not available' do
          before do
            allow(Security::PolicySetting).to receive(:in_organization).and_return(nil)
          end

          it 'does not raise NoMethodError' do
            expect { configurations }.not_to raise_error
          end
        end

        context 'with a designated CSP group' do
          include_context 'with csp group configuration'

          it 'returns security policy configurations including the CSP configuration' do
            expect(configurations).to contain_exactly(
              csp_security_orchestration_policy_configuration,
              parent_security_orchestration_policy_configuration,
              child_security_orchestration_policy_configuration,
              child_security_orchestration_policy_configuration_2,
              project_security_orchestration_policy_configuration
            )
          end
        end
      end
    end
  end

  describe '#all_inherited_security_orchestration_policy_configurations' do
    subject(:configurations) { project.all_inherited_security_orchestration_policy_configurations }

    let_it_be(:parent_group) { create(:group) }
    let_it_be(:child_group) { create(:group, parent: parent_group) }
    let_it_be(:child_group_2) { create(:group, parent: child_group) }
    let_it_be_with_refind(:project) { create(:project, group: child_group_2) }

    let_it_be(:parent_security_orchestration_policy_configuration) { create(:security_orchestration_policy_configuration, :namespace, namespace: parent_group) }
    let_it_be(:child_security_orchestration_policy_configuration) { create(:security_orchestration_policy_configuration, :namespace, namespace: child_group) }
    let_it_be(:child_security_orchestration_policy_configuration_2) { create(:security_orchestration_policy_configuration, :namespace, namespace: child_group_2) }

    let_it_be(:project_security_orchestration_policy_configuration) do
      create(:security_orchestration_policy_configuration, project: project)
    end

    context 'when configuration is invalid' do
      before do
        allow_next_found_instances_of(Security::OrchestrationPolicyConfiguration, 4) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(false)
        end
      end

      it 'returns security policy configurations for all valid parent groups and project' do
        expect(configurations).to be_empty
      end
    end

    context 'when configuration is valid' do
      before do
        allow_next_found_instances_of(Security::OrchestrationPolicyConfiguration, 4) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
        end
      end

      it 'returns security policy configurations for all valid parent groups only' do
        expect(configurations).to match_array(
          [
            parent_security_orchestration_policy_configuration,
            child_security_orchestration_policy_configuration,
            child_security_orchestration_policy_configuration_2
          ]
        )
      end

      context 'with a designated CSP group' do
        include_context 'with csp group configuration'

        it 'returns security policy configurations including the CSP configuration' do
          expect(configurations).to contain_exactly(
            csp_security_orchestration_policy_configuration,
            parent_security_orchestration_policy_configuration,
            child_security_orchestration_policy_configuration,
            child_security_orchestration_policy_configuration_2
          )
        end
      end
    end
  end

  describe '#dormant?' do
    context 'when Gitlab.com', :saas do
      context 'when project belongs to paid namespace' do
        before do
          stub_application_setting(inactive_projects_min_size_mb: 5)
          stub_application_setting(inactive_projects_send_warning_email_after_months: 24)
        end

        it 'returns false' do
          ultimate_group = create(:group_with_plan, plan: :ultimate_plan)
          ultimate_project = create(:project, last_activity_at: 3.years.ago, namespace: ultimate_group)

          expect(ultimate_project.dormant?).to be(false)
        end
      end

      context 'when project belongs to free namespace' do
        let_it_be(:no_plan_group) { create(:group_with_plan, plan: nil) }
        let_it_be_with_reload(:project) { create(:project, namespace: no_plan_group) }

        it_behaves_like 'returns true if project is dormant'
      end
    end

    context 'when not Gitlab.com' do
      let_it_be_with_reload(:project) { create(:project, name: 'test-project') }

      it_behaves_like 'returns true if project is dormant'
    end
  end

  describe '.dormant', :saas do
    before do
      stub_application_setting(inactive_projects_min_size_mb: 5)
      stub_application_setting(inactive_projects_send_warning_email_after_months: 24)
    end

    it 'returns dormant projects belonging to free namespace' do
      ultimate_group = create(:group_with_plan, plan: :ultimate_plan)
      premium_group = create(:group_with_plan, plan: :premium_plan)
      free_plan_group = create(:group_with_plan, plan: :free_plan)

      free_small_active_project =
        create_project_with_statistics(free_plan_group, with_data: true, size_multiplier: 1.kilobyte).tap do |project|
          project.update!(last_activity_at: 7.days.ago)
        end

      free_small_dormant_project =
        create_project_with_statistics(free_plan_group, with_data: true, size_multiplier: 1.kilobyte).tap do |project|
          project.update!(last_activity_at: 3.years.ago)
        end

      free_large_dormant_project =
        create_project_with_statistics(free_plan_group, with_data: true, size_multiplier: 10.megabytes).tap do |project|
          project.update!(last_activity_at: 3.years.ago)
        end

      free_large_active_project =
        create_project_with_statistics(free_plan_group, with_data: true, size_multiplier: 10.megabytes).tap do |project|
          project.update!(last_activity_at: 7.days.ago)
        end

      paid_small_active_project =
        create_project_with_statistics(premium_group, with_data: true, size_multiplier: 1.megabyte).tap do |project|
          project.update!(last_activity_at: 7.days.ago)
        end

      paid_small_dormant_project =
        create_project_with_statistics(premium_group, with_data: true, size_multiplier: 1.megabyte).tap do |project|
          project.update!(last_activity_at: 7.years.ago)
        end

      paid_large_dormant_project =
        create_project_with_statistics(ultimate_group, with_data: true, size_multiplier: 1.gigabyte).tap do |project|
          project.update!(last_activity_at: 7.years.ago)
        end

      expect(described_class.dormant).to contain_exactly(free_large_dormant_project)
      expect(described_class.dormant).not_to include(
        free_small_active_project, free_small_dormant_project, free_large_active_project,
        paid_small_active_project, paid_small_dormant_project, paid_large_dormant_project
      )
    end
  end

  describe '#security_training_available?' do
    let(:namespace) { build(:namespace) }
    let(:project) { build(:project, namespace: namespace) }

    subject { project.security_training_available? }

    context 'when check_namespace_plan application setting is true' do
      before do
        stub_application_setting(check_namespace_plan: true)
        allow(namespace).to receive(:actual_plan) { plan_license }
      end

      context 'when plan is not ultimate' do
        let(:plan_license) { build(:starter_plan) }

        it { is_expected.to be false }
      end

      context 'when plan is ultimate' do
        let(:plan_license) { build(:ultimate_plan) }

        context 'when security_training feature is not available' do
          it { is_expected.to be false }
        end

        context 'when security_training feature is available' do
          before do
            stub_licensed_features(security_training: true)
          end

          it { is_expected.to be true }
        end
      end
    end

    context 'when check_namespace_plan application setting is false' do
      context 'when security_training feature is not available' do
        it { is_expected.to be false }
      end

      context 'when security_training feature is available' do
        before do
          stub_licensed_features(security_training: true)
        end

        it { is_expected.to be true }
      end
    end
  end

  describe '#epic_ids_referenced_by_issues' do
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:project) { create(:project, group: subgroup) }
    let_it_be(:issue1) { create(:issue, project: project) }
    let_it_be(:issue2) { create(:issue, project: project) }
    let_it_be(:epic1) { create(:epic, group: group) }
    let_it_be(:epic2) { create(:epic, group: subgroup) }
    let_it_be(:unrelated_epic) { create(:epic, group: subgroup) }
    let_it_be(:epic_issue1) { create(:epic_issue, epic: epic1, issue: issue1) }
    let_it_be(:epic_issue2) { create(:epic_issue, epic: epic2, issue: issue2) }

    it 'returns epic ids referenced by issues in this project' do
      stub_const('Project::ISSUE_BATCH_SIZE', 1)

      expect(project.epic_ids_referenced_by_issues).to match_array([epic1.id, epic2.id])
    end
  end

  describe '#suggested_reviewers_available?' do
    subject { project.suggested_reviewers_available? }

    context 'on Gitlab.com', :saas do
      context 'when licensed features are available', :saas do
        before do
          stub_licensed_features(suggested_reviewers: true)
        end

        it { is_expected.to be false }
      end

      context 'when licensed features are unavailable', :saas do
        before do
          stub_licensed_features(suggested_reviewers: false)
        end

        it { is_expected.to be false }
      end

      context 'when hide_suggested_reviewers feature flag is disabled', :saas do
        before do
          stub_licensed_features(suggested_reviewers: true)
          stub_feature_flags(hide_suggested_reviewers: false)
        end

        it { is_expected.to be true }
      end
    end

    context 'on self managed' do
      context 'when licensed features are available' do
        before do
          stub_licensed_features(suggested_reviewers: true)
        end

        it { is_expected.to be false }
      end
    end
  end

  describe '#can_suggest_reviewers?' do
    subject { project.can_suggest_reviewers? }

    context 'when available' do
      before do
        allow(project).to receive(:suggested_reviewers_available?).and_return(true)
      end

      context 'when enabled' do
        before do
          allow(project).to receive(:suggested_reviewers_enabled).and_return(true)
        end

        it { is_expected.to be true }
      end

      context 'when not enabled' do
        before do
          allow(project).to receive(:suggested_reviewers_enabled).and_return(false)
        end

        it { is_expected.to be false }
      end
    end

    context 'when not available' do
      before do
        allow(project).to receive(:suggested_reviewers_available?).and_return(false)
      end

      context 'when enabled' do
        before do
          allow(project).to receive(:suggested_reviewers_enabled).and_return(true)
        end

        it { is_expected.to be false }
      end
    end
  end

  describe '#any_external_status_checks_not_passed?' do
    let(:protected_branch) { create(:protected_branch, name: 'main', project: project) }
    let(:merge_request) { create(:merge_request, source_project: project, target_project: project, target_branch: protected_branch.name) }

    subject { project.any_external_status_checks_not_passed?(merge_request) }

    before do
      allow(merge_request).to receive(:diff_head_sha).and_return('abcd1234')
    end

    context 'when no external status checks are present' do
      it { is_expected.to be_falsey }
    end

    context 'when merge request branch is applicable' do
      let(:status_check) { create(:external_status_check, project: project, protected_branches: [protected_branch]) }

      context 'when all external status checks have passed' do
        before do
          create(:status_check_response, merge_request: merge_request, external_status_check: status_check, sha: merge_request.diff_head_sha, status: 'passed')
        end

        it { is_expected.to be_falsey }
      end

      context 'when not all external status checks have passed' do
        before do
          create(:status_check_response, merge_request: merge_request, external_status_check: status_check, sha: merge_request.diff_head_sha, status: 'passed')
          create(:status_check_response, merge_request: merge_request, external_status_check: status_check, sha: merge_request.diff_head_sha, status: 'failed')
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'when merge request branch is non applicable' do
      let(:status_check) { create(:external_status_check, project: project, protected_branches: []) }

      before do
        create(:status_check_response, merge_request: merge_request, sha: merge_request.diff_head_sha, status: 'passed')
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '.cascading_with_parent_namespace' do
    before do
      stub_licensed_features(group_level_merge_checks_setting: true)
    end

    context "when calling .cascading_with_parent_namespace" do
      it 'create three instance methods for attribute' do
        EE::Project.cascading_with_parent_namespace("any_configuration")
        expect(EE::Project.instance_methods).to include(
          :any_configuration_of_parent_group, :any_configuration_locked?, :any_configuration?)
      end
    end

    context 'three configurations of MR checks' do
      let_it_be_with_reload(:group) { create(:group) }
      let_it_be_with_reload(:subgroup) { create(:group, parent: group) }
      let_it_be_with_reload(:project) { create(:project, group: subgroup) }

      shared_examples '[configuration](inherit_group_setting: bool) and [configuration]_locked?' do |attribute|
        where(:group_attr, :subgroup_attr, :project_attr, :group_with_inherit_attr?, :group_without_inherit_attr?, :group_locked?, :subgroup_with_inherit_attr?, :subgroup_without_inherit_attr?, :subgroup_locked?, :project_with_inherit_attr?, :project_without_inherit_attr?, :project_locked?) do
          true  | true  | true      | true  | true  | false     | true  | true  | true      | true  | true  | true
          true  | true  | false     | true  | true  | false     | true  | true  | true      | true  | false | true
          true  | false | false     | true  | true  | false     | true  | false | true      | true  | false | true
          false | true  | true      | false | false | false     | true  | true  | false     | true  | true  | true
          false | true  | false     | false | false | false     | true  | true  | false     | true  | false | true
          false | false | false     | false | false | false     | false | false | false     | false | false | false
        end

        with_them do
          before do
            group.namespace_settings.update!(attribute => group_attr)
            subgroup.namespace_settings.update!(attribute => subgroup_attr)
            project.update!(attribute => project_attr)
          end

          it 'returns correct value' do
            expect(group.namespace_settings.public_send("#{attribute}?", inherit_group_setting: true)).to eq(group_with_inherit_attr?)
            expect(group.namespace_settings.public_send("#{attribute}?", inherit_group_setting: false)).to eq(group_without_inherit_attr?)
            expect(group.namespace_settings.public_send("#{attribute}_locked?")).to eq(group_locked?)

            expect(subgroup.namespace_settings.public_send("#{attribute}?", inherit_group_setting: true)).to eq(subgroup_with_inherit_attr?)
            expect(subgroup.namespace_settings.public_send("#{attribute}?", inherit_group_setting: false)).to eq(subgroup_without_inherit_attr?)
            expect(subgroup.namespace_settings.public_send("#{attribute}_locked?")).to eq(subgroup_locked?)

            expect(project.public_send("#{attribute}?", inherit_group_setting: true)).to eq(project_with_inherit_attr?)
            expect(project.public_send("#{attribute}?", inherit_group_setting: false)).to eq(project_without_inherit_attr?)
            expect(project.public_send("#{attribute}_locked?")).to eq(project_locked?)
          end
        end
      end

      it_behaves_like '[configuration](inherit_group_setting: bool) and [configuration]_locked?', :only_allow_merge_if_pipeline_succeeds
      it_behaves_like '[configuration](inherit_group_setting: bool) and [configuration]_locked?', :allow_merge_on_skipped_pipeline
      it_behaves_like '[configuration](inherit_group_setting: bool) and [configuration]_locked?', :only_allow_merge_if_all_discussions_are_resolved
    end
  end

  shared_examples 'configuration method with security policy bypass' do |attribute, default_value|
    let_it_be_with_refind(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }

    before do
      stub_licensed_features(security_orchestration_policies: true, group_level_merge_checks_setting: true)
      project.update!(attribute => default_value)
    end

    context 'when project is not a security policy project' do
      it "returns #{default_value}" do
        expect(project.public_send("#{attribute}?")).to eq(default_value)
      end

      context 'when group has different value' do
        before do
          group.namespace_settings.update!(attribute => !default_value)
        end

        it 'inherits from group when inherit_group_setting is true' do
          expect(project.public_send("#{attribute}?", inherit_group_setting: true)).to eq(!default_value)
        end

        it 'uses project value when inherit_group_setting is false' do
          expect(project.public_send("#{attribute}?", inherit_group_setting: false)).to eq(default_value)
        end
      end
    end

    context 'when project is a security policy project' do
      before do
        create(:security_orchestration_policy_configuration, security_policy_management_project: project)
        project.update!(attribute => !default_value)
        group.namespace_settings.update!(attribute => default_value)
      end

      it "returns #{!default_value} (bypasses group inheritance)" do
        expect(project.public_send("#{attribute}?")).to eq(!default_value)
      end
    end

    context 'when security_orchestration_policies license is not available' do
      before do
        stub_licensed_features(security_orchestration_policies: false, group_level_merge_checks_setting: true)
        create(:security_orchestration_policy_configuration, security_policy_management_project: project)
        project.update!(attribute => !default_value)
        group.namespace_settings.update!(attribute => default_value)
      end

      it 'returns project or group value when inherit_group_setting is true' do
        expected_result = project.public_send(attribute) || project.public_send("#{attribute}_of_parent_group")

        result = project.public_send("#{attribute}?", inherit_group_setting: true)
        expect(result).to eq(expected_result)
      end

      it 'uses project value when inherit_group_setting is false' do
        expect(project.public_send("#{attribute}?", inherit_group_setting: false)).to eq(!default_value)
      end
    end
  end

  shared_examples 'configuration locked method with security policy bypass' do |attribute|
    let_it_be_with_refind(:group) { create(:group) }
    let_it_be_with_refind(:project) { create(:project, group: group) }

    before do
      stub_licensed_features(group_level_merge_checks_setting: true)
    end

    context 'when project is not a security policy project' do
      before do
        group.namespace_settings.update!(attribute => true)
      end

      it 'returns group value' do
        expect(project.public_send("#{attribute}_locked?")).to be_truthy
      end
    end

    context 'when project is a security policy project' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
        create(:security_orchestration_policy_configuration, security_policy_management_project: project)
        group.namespace_settings.update!(attribute => true)
      end

      it 'returns false (bypasses group inheritance)' do
        expect(project.public_send("#{attribute}_locked?")).to be_falsey
      end
    end

    context 'when group_level_merge_checks_setting license is not available' do
      before do
        stub_licensed_features(group_level_merge_checks_setting: false)
        group.namespace_settings.update!(attribute => true)
      end

      it 'calls super and returns result' do
        expect { project.public_send("#{attribute}_locked?") }.not_to raise_error
      end
    end
  end

  describe '#only_allow_merge_if_pipeline_succeeds?' do
    it_behaves_like 'configuration method with security policy bypass', :only_allow_merge_if_pipeline_succeeds, false
  end

  describe '#only_allow_merge_if_pipeline_succeeds_locked?' do
    it_behaves_like 'configuration locked method with security policy bypass', :only_allow_merge_if_pipeline_succeeds
  end

  describe '#allow_merge_on_skipped_pipeline?' do
    it_behaves_like 'configuration method with security policy bypass', :allow_merge_on_skipped_pipeline, false
  end

  describe '#allow_merge_on_skipped_pipeline_locked?' do
    it_behaves_like 'configuration locked method with security policy bypass', :allow_merge_on_skipped_pipeline
  end

  describe '#okrs_mvc_feature_flag_enabled?' do
    let_it_be(:project) { create(:project) }

    it 'returns true if feature_flag is enabled' do
      expect(project.okrs_mvc_feature_flag_enabled?).to be_truthy
    end

    it 'returns false if feature_flag is disabled' do
      stub_feature_flags(okrs_mvc: false)
      expect(project.okrs_mvc_feature_flag_enabled?).to be_falsey
    end
  end

  describe '#custom_roles_enabled?' do
    context 'project belongs to group' do
      let_it_be(:project) { create(:project, :in_group) }

      context 'root ancestor has custom roles enabled' do
        it 'returns true' do
          allow(project.root_ancestor).to receive(:custom_roles_enabled?).and_return(true)

          expect(project.custom_roles_enabled?).to be true
        end
      end

      context 'root ancestor does not have custom roles enabled' do
        it 'returns false' do
          expect(project.custom_roles_enabled?).to be false
        end
      end
    end

    context 'project belongs to user' do
      it 'returns false' do
        expect(project.custom_roles_enabled?).to be false
      end
    end
  end

  describe '#project_epics_enabled?' do
    let_it_be(:project_in_group) { create(:project, :in_group) }
    let_it_be(:group) { project_in_group.group }

    where(:license, :feature_flag_actor, :object, :result) do
      false | false | ref(:project) | false
      false | ref(:project) | ref(:project) | false
      false | ref(:group) | ref(:project_in_group) | false
      true | false | ref(:project) | false
      true | ref(:project) | ref(:project) | true
      true | ref(:group) | ref(:project_in_group) | true
    end

    with_them do
      it 'returns the right value' do
        stub_licensed_features(epics: license)
        stub_feature_flags(project_work_item_epics: feature_flag_actor)

        expect(object.project_epics_enabled?).to be(result)
      end
    end
  end

  describe '#mirror_branches_setting' do
    it 'mirror all branches' do
      project = build(:project, only_mirror_protected_branches: false, mirror_branch_regex: nil)

      expect(project.mirror_branches_setting).to eq('all')
    end

    it 'mirror protected branches' do
      project = build(:project, only_mirror_protected_branches: true, mirror_branch_regex: nil)

      expect(project.mirror_branches_setting).to eq('protected')
    end

    it 'mirror branches match regex' do
      project = build(:project, only_mirror_protected_branches: false, mirror_branch_regex: 'text')

      expect(project.mirror_branches_setting).to eq('regex')
    end
  end

  describe '#merge_train_for' do
    subject { project.merge_train_for(project.default_branch) }

    before do
      allow(project).to receive(:merge_trains_enabled?).and_return(setting)
    end

    context 'with merge_trains_enabled' do
      let(:setting) { true }

      it { is_expected.to be_a(MergeTrains::Train) }
    end

    context 'with merge_trains disabled' do
      let(:setting) { false }

      it { is_expected.to be_nil }
    end
  end

  describe 'deprecated requirements_enabled attribute' do
    it 'delegates the attribute to project feature' do
      project = described_class.new(requirements_enabled: false)

      expect(project.project_feature.requirements_access_level).to eq(ProjectFeature::DISABLED)
    end

    it 'sets the default value' do
      project = described_class.new

      expect(project.project_feature.requirements_access_level).to eq(ProjectFeature::ENABLED)
    end
  end

  describe '#security_policy_bot' do
    let_it_be(:project) { create(:project) }

    subject { project.security_policy_bot }

    it { is_expected.to be_nil }

    context "when there is a security_policy_bot" do
      let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

      it { is_expected.to be_nil }

      context "when the security_policy_bot is assigned to the project" do
        before_all do
          project.add_guest(security_policy_bot)
        end

        it { is_expected.to eq security_policy_bot }
      end
    end
  end

  describe '#github_external_pull_request_pipelines_available?' do
    let_it_be(:project) { create(:project, :mirror) }

    subject { project.github_external_pull_request_pipelines_available? }

    context 'when enabled through license' do
      before do
        stub_licensed_features(ci_cd_projects: true, github_integration: true, repository_mirrors: true)
      end

      it { is_expected.to be_truthy }
    end

    context 'when enabled through usage ping features' do
      before do
        stub_usage_ping_features(true)
      end

      it { is_expected.to be_truthy }
    end

    context 'without license' do
      before do
        stub_licensed_features(ci_cd_projects: false, github_integration: false, repository_mirrors: false)
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#allows_multiple_merge_request_assignees?' do
    let(:project) { build_stubbed(:project) }

    subject(:allows_multiple_merge_request_assignees?) { project.allows_multiple_merge_request_assignees? }

    context 'when multiple_merge_request_assignees feature is enabled' do
      before do
        stub_licensed_features(multiple_merge_request_assignees: true)
      end

      it { is_expected.to be(true) }
    end

    context 'when multiple_merge_request_assignees feature is disabled' do
      before do
        stub_licensed_features(multiple_merge_request_assignees: false)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#allows_multiple_merge_request_reviewers?' do
    let(:project) { build_stubbed(:project) }

    subject(:allows_multiple_merge_request_reviewers?) { project.allows_multiple_merge_request_reviewers? }

    context 'when multiple_merge_request_reviewers feature is enabled' do
      before do
        stub_licensed_features(multiple_merge_request_reviewers: true)
      end

      it { is_expected.to be(true) }
    end

    context 'when multiple_merge_request_reviewers feature is disabled' do
      before do
        stub_licensed_features(multiple_merge_request_reviewers: false)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#on_demand_dast_available?' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:project) { create(:project) }

    subject(:on_demand_dast_available?) { project.on_demand_dast_available? }

    where(:feature_available, :on_demand_available) do
      false | false
      true | true
    end
    with_them do
      context "when feature is #{params[:feature_available] ? 'allowed' : 'disallowed'}" do
        before do
          stub_licensed_features(security_on_demand_scans: feature_available)
        end

        it do
          is_expected.to eq(on_demand_available)
        end
      end
    end
  end

  describe '#supports_saved_replies?' do
    subject(:supported) { project.supports_saved_replies? }

    context 'when license is invalid' do
      before do
        stub_licensed_features(project_saved_replies: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when license is valid' do
      before do
        stub_licensed_features(project_saved_replies: true)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '#licensed_ai_features_available?' do
    subject { project.licensed_ai_features_available? }

    where(:ai_features, :ai_chat, :licensed_ai_features_available) do
      true | true | true
      true | false | true
      false | true | true
      false | false | false
    end

    with_them do
      before do
        stub_licensed_features(ai_features: ai_features, ai_chat: ai_chat)
      end

      it { is_expected.to be(licensed_ai_features_available) }
    end

    context 'when on SaaS with an active gitlab_credits add-on', :saas do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }

      before do
        stub_licensed_features(ai_features: false, ai_chat: false)
        stub_saas_features(gitlab_duo_saas_only: true)
        create(:gitlab_subscription_add_on_purchase, :gitlab_credits, namespace: group)
      end

      it { is_expected.to be_truthy }
    end

    context 'when self-managed with an active gitlab_credits add-on' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }

      before do
        stub_licensed_features(ai_features: false, ai_chat: false)
        create(:gitlab_subscription_add_on_purchase, :gitlab_credits, :self_managed,
          organization: group.organization)
      end

      it { is_expected.to be_truthy }
    end
  end

  describe '#path_locks_changed_epoch', :clean_gitlab_redis_cache do
    let(:project) { build(:project, id: 1) }
    let(:epoch) { Time.current.strftime('%s%L').to_i }

    it 'returns a cached epoch value in milliseconds', :aggregate_failures, :freeze_time do
      cold_cache_control = RedisCommands::Recorder.new do
        expect(project.path_locks_changed_epoch).to eq epoch
      end

      expect(cold_cache_control.by_command('get').count).to eq 1
      expect(cold_cache_control.by_command('set').count).to eq 1

      warm_cache_control = RedisCommands::Recorder.new do
        expect(project.path_locks_changed_epoch).to eq epoch
      end

      expect(warm_cache_control.by_command('get').count).to eq 1
      expect(warm_cache_control.by_command('set').count).to eq 0
    end
  end

  describe '#refresh_path_locks_changed_epoch' do
    let(:project) { build(:project, id: 1) }
    let(:original_time) { Time.current }
    let(:refresh_time) { original_time + 1.second }
    let(:original_epoch) { original_time.strftime('%s%L').to_i }
    let(:refreshed_epoch) { original_epoch + 1.second.in_milliseconds }

    it 'refreshes the cache and returns the new epoch value', :aggregate_failures, :freeze_time do
      expect(project.path_locks_changed_epoch).to eq(original_epoch)

      travel_to(refresh_time)

      expect(project.path_locks_changed_epoch).to eq(original_epoch)

      control = RedisCommands::Recorder.new do
        expect(project.refresh_path_locks_changed_epoch).to eq(refreshed_epoch)
      end
      expect(control.by_command('get').count).to eq 0
      expect(control.by_command('set').count).to eq 1

      expect(project.path_locks_changed_epoch).to eq(refreshed_epoch)
    end
  end

  describe '#mark_as_vulnerable!' do
    subject(:mark_as_vulnerable!) { project.mark_as_vulnerable! }

    it 'marks the project as vulnerable' do
      expect { mark_as_vulnerable! }.to change { project.project_setting.has_vulnerabilities }.to(true)
    end
  end

  describe '#compliance_management_frameworks_names' do
    let_it_be(:project) { create(:project, :with_multiple_compliance_frameworks) }

    it 'returns names of all compliance frameworks' do
      expect(project.compliance_management_frameworks_names).to contain_exactly('SOX', 'GDPR')
    end
  end

  describe '#compliance_framework_ids' do
    subject { project.compliance_framework_ids }

    let_it_be(:project) { create(:project) }
    let_it_be(:compliance_framework_1) { create(:compliance_framework_project_setting, project: project) }
    let_it_be(:compliance_framework_2) { create(:compliance_framework_project_setting, :sox, project: project) }

    it { is_expected.to contain_exactly(compliance_framework_1.framework_id, compliance_framework_2.framework_id) }
  end

  describe '#prevent_blocking_non_deployment_jobs?' do
    let_it_be_with_refind(:project) { create(:project, :stubbed_repository) }

    subject { project.prevent_blocking_non_deployment_jobs? }

    it { is_expected.to be(true) }

    context 'when the prevent_blocking_non_deployment_jobs feature flag is disabled' do
      before do
        stub_feature_flags(prevent_blocking_non_deployment_jobs: false)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#pages_domain_level_parallel_deployments_count' do
    subject(:deployment_count) { project.pages_domain_level_parallel_deployments_count }

    let(:group) { create(:group) }
    let(:project) { create(:project, group: group) }

    before do
      project.actual_limits.update!(active_versioned_pages_deployments_limit_by_namespace: 10)
    end

    context 'when the project uses a unique domain' do
      before do
        project.project_setting.update!(
          pages_unique_domain_enabled: true,
          pages_unique_domain: 'unique.example.com'
        )
        create_list(:pages_deployment, 2, project: project, path_prefix: 'version')
      end

      it 'returns the project deployment count' do
        expect(deployment_count).to eq(project.pages_parallel_deployments_count)
      end
    end

    context 'when the project uses the namespace domain' do
      before do
        project.project_setting.update!(pages_unique_domain_enabled: false)
        create_list(:pages_deployment, 2, project: project, path_prefix: 'version')
      end

      it 'counts the project deployments' do
        expect(deployment_count).to eq(2)
      end
    end

    context 'when the root namespace has mixed domain settings' do
      before do
        project.project_setting.update!(pages_unique_domain_enabled: false)
        namespace_domain_project = create(:project, group: group)
        namespace_domain_project.project_setting.update!(pages_unique_domain_enabled: false)
        unique_domain_project = create(:project, group: group)
        unique_domain_project.project_setting.update!(
          pages_unique_domain_enabled: true,
          pages_unique_domain: 'unique.example.com'
        )
        create_list(:pages_deployment, 2, project: project, path_prefix: 'version')
        create(:pages_deployment, project: namespace_domain_project, path_prefix: 'version')
        create_list(:pages_deployment, 2, project: unique_domain_project, path_prefix: 'version')
      end

      it 'counts only namespace-domain deployments' do
        expect(deployment_count).to eq(3)
      end
    end
  end

  describe '#vulnerability_quota' do
    subject { project.vulnerability_quota }

    it { is_expected.to be_an_instance_of(Vulnerabilities::Quota) }
  end

  describe '#pipeline_configuration_full_path' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project) { create(:project, group: namespace) }
    let_it_be(:framework_1_with_pipeline) { create(:compliance_framework, namespace: namespace, name: 'With pipeline 1', pipeline_configuration_full_path: ".compliance-gitlab-ci.yml@test-project-1") }
    let_it_be(:framework_2_with_pipeline) { create(:compliance_framework, namespace: namespace, name: 'With pipeline 2', pipeline_configuration_full_path: ".compliance-gitlab-ci.yml@test-project-2") }
    let_it_be(:framework_1_without_pipeline) { create(:compliance_framework, namespace: namespace, name: 'Without pipeline 1') }
    let_it_be(:framework_2_without_pipeline) { create(:compliance_framework, namespace: namespace, name: 'Without pipeline 2') }

    context 'when the first associated framework has pipeline configuration' do
      let_it_be(:framework_settings_1) { create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework_1_with_pipeline) }
      let_it_be(:framework_settings_2) { create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework_2_with_pipeline) }

      it 'returns the path of pipeline config associated with first framework' do
        expect(project.pipeline_configuration_full_path).to eq(framework_1_with_pipeline.pipeline_configuration_full_path)
      end
    end

    context 'when no framework has pipeline configuration' do
      let_it_be(:framework_settings_1) { create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework_1_without_pipeline) }
      let_it_be(:framework_settings_2) { create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework_2_without_pipeline) }

      it 'returns nil' do
        expect(project.pipeline_configuration_full_path).to be_nil
      end
    end

    context 'when initial frameworks do not have pipeline configuration' do
      let_it_be(:framework_settings_1) { create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework_1_without_pipeline) }
      let_it_be(:framework_settings_2) { create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework_2_without_pipeline) }
      let_it_be(:framework_settings_3) { create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework_2_with_pipeline) }
      let_it_be(:framework_settings_4) { create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework_1_with_pipeline) }

      it 'returns the pipeline of first framework which has pipeline' do
        expect(project.pipeline_configuration_full_path).to eq(framework_2_with_pipeline.pipeline_configuration_full_path)
      end
    end

    context 'when there is no associated framework' do
      it 'returns nil' do
        expect(project.pipeline_configuration_full_path).to be_nil
      end
    end
  end

  describe '#security_statistics' do
    let_it_be(:project) { create(:project) }

    subject(:security_statistics) { project.security_statistics }

    context 'when there is no `project_security_statistics` for the project' do
      it 'returns a new persisted `Security::ProjectStatistics` instance' do
        expect(security_statistics).to be_an_instance_of(Security::ProjectStatistics)
                                   .and have_attributes(project_id: project.id)
      end

      it 'does not fire additional queries after the first access' do
        security_statistics # warmup

        queries = ActiveRecord::QueryRecorder.new { security_statistics }

        expect(queries.count).to be_zero
      end
    end

    context 'when there is already a `project_security_statistics` for the project' do
      let_it_be(:statistics) { create(:project_security_statistics, project: project) }

      it 'returns the existing record' do
        expect(security_statistics).to eq(statistics)
      end
    end
  end

  describe '#ai_review_merge_request_allowed?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:current_user) { create(:user) }

    it 'delegates to Gitlab::Duo::CodeReview' do
      expect(Gitlab::Duo::CodeReview).to receive(:enabled?).with(user: current_user, container: project).and_call_original

      project.ai_review_merge_request_allowed?(current_user)
    end
  end

  describe 'Geo replication', feature_category: :geo_replication do
    describe 'associations' do
      it do
        is_expected.to have_one(:project_state)
          .class_name('Geo::ProjectState')
          .inverse_of(:project)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let(:verifiable_model_record) { build(:project) }
      let(:unverifiable_model_record) { nil }
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }

      # Project for the root group
      let_it_be(:first_replicable_and_in_selective_sync) { create(:project, group: group_1) }
      # Project for a subgroup
      let_it_be(:second_replicable_and_in_selective_sync) { create(:project, group: nested_group_1) }
      # Project in a shard name that doesn't actually exist
      let_it_be(:last_replicable_and_not_in_selective_sync) { create(:project, :broken_storage, group: group_2) }

      include_examples 'Geo Framework selective sync behavior'
    end
  end

  describe '#vulnerability_archival_enabled?' do
    let_it_be(:root_ancestor) { create(:group) }
    let_it_be(:group) { create(:group, parent: root_ancestor) }
    let_it_be_with_refind(:project) { create(:project, group: group) }

    subject { project.vulnerability_archival_enabled? }

    it { is_expected.to be_truthy }

    context 'when the feature is disabled for the direct parent' do
      before do
        stub_feature_flags(vulnerability_archival: false)
      end

      context 'when the feature is disabled for the root ancestor' do
        it { is_expected.to be_falsey }
      end

      context 'when the feature is enabled for the root ancestor' do
        before do
          stub_feature_flags(vulnerability_archival: root_ancestor)
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'when the feature is disabled for the direct parent' do
      before do
        stub_feature_flags(vulnerability_archival: group)
      end

      context 'when the feature is disabled for the root ancestor' do
        it { is_expected.to be_truthy }
      end

      context 'when the feature is enabled for the root ancestor' do
        before do
          stub_feature_flags(vulnerability_archival: root_ancestor)
        end

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '#auto_duo_code_review_settings_available?' do
    let_it_be_with_refind(:namespace) { create(:group) }
    let_it_be(:project) { create(:project, group: namespace) }
    let_it_be(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
    let_it_be(:duo_core_add_on) { create(:gitlab_subscription_add_on, :duo_core) }
    let_it_be(:self_hosted_dap_add_on) { create(:gitlab_subscription_add_on, :self_hosted_dap) }
    let_it_be(:code_review_foundational_flow) { create(:ai_catalog_item, :with_foundational_flow_reference) }

    subject { project.auto_duo_code_review_settings_available? }

    context 'when duo_features_enabled is false' do
      before do
        allow(project).to receive(:duo_features_enabled).and_return(false)
      end

      it 'returns false' do
        expect(subject).to be false
      end
    end

    context 'when duo_features_enabled is true' do
      before do
        allow(project).to receive(:duo_features_enabled).and_return(true)
      end

      context 'without any add-on' do
        it { is_expected.to be_falsey }
      end

      context 'on SaaS', :saas do
        before do
          stub_ee_application_setting(should_check_namespace_plan: true)
          allow(::Ai::Catalog::FoundationalFlow).to receive(:[])
            .with('code_review/v1')
            .and_return(
              instance_double(::Ai::Catalog::FoundationalFlow, catalog_item: code_review_foundational_flow)
            )
        end

        context 'when duo_foundational_flows_enabled is false' do
          before do
            allow(project).to receive(:duo_foundational_flows_enabled).and_return(false)
            create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: duo_core_add_on)
          end

          it 'returns false even with duo_core add-on' do
            expect(subject).to be_falsey
          end
        end

        context 'when code_review workflow definition is nil' do
          before do
            allow(project).to receive(:duo_foundational_flows_enabled).and_return(true)
            allow(::Ai::Catalog::FoundationalFlow).to receive(:[])
              .with('code_review/v1')
              .and_return(nil)
            create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: duo_core_add_on)
          end

          it { is_expected.to be_falsey }
        end

        context 'when duo_foundational_flows_enabled is true' do
          before do
            allow(project).to receive(:duo_foundational_flows_enabled).and_return(true)
          end

          context 'when code_review flow is not enabled' do
            before do
              allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                .with(project, :duo_workflow).and_return(true)
              create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: duo_core_add_on)
            end

            it 'returns false with duo_core add-on' do
              expect(subject).to be_falsey
            end
          end

          context 'when code_review flow is enabled' do
            before do
              create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace, catalog_item: code_review_foundational_flow)
            end

            context 'when StageCheck returns false' do
              before do
                allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                  .with(project, :duo_workflow).and_return(false)
                create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: duo_core_add_on)
              end

              it 'returns false with duo_core add-on' do
                expect(subject).to be_falsey
              end
            end

            context 'when StageCheck returns true' do
              where(:add_on_type, :add_on) do
                [
                  ['duo_core',       ref(:duo_core_add_on)],
                  ['duo_pro',        lazy { create(:gitlab_subscription_add_on, :duo_pro) }],
                  ['duo_enterprise', ref(:duo_enterprise_add_on)]
                ]
              end

              with_them do
                before do
                  create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on)
                  allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                    .with(project, :duo_workflow).and_return(true)
                end

                it "returns true for #{params[:add_on_type]}" do
                  expect(subject).to be_truthy
                end
              end

              context 'when StageCheck returns true without any paid add-on' do
                before do
                  allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                    .with(project, :duo_workflow).and_return(true)
                end

                it 'returns true for Free tier when DAP code review is available' do
                  expect(subject).to be_truthy
                end
              end
            end

            context 'when duo_foundational_flows_enabled differs between namespace and project' do
              before do
                namespace.namespace_settings.update!(duo_foundational_flows_enabled: true)
                allow(project).to receive(:duo_foundational_flows_enabled).and_return(false)
                create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: duo_core_add_on)
              end

              it 'returns false because project setting is used' do
                expect(subject).to be_falsey
              end
            end
          end
        end
      end

      context 'on self-managed' do
        context 'when duo_foundational_flows_enabled is false' do
          where(:add_on_type) do
            [ref(:duo_core_add_on), ref(:self_hosted_dap_add_on)]
          end

          with_them do
            before do
              allow(project).to receive(:duo_foundational_flows_enabled).and_return(false)
              create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: add_on_type)
            end

            it "returns false for #{params[:add_on_type]}" do
              expect(subject).to be_falsey
            end
          end
        end

        context 'when code_review workflow definition is nil' do
          where(:add_on_type) do
            [ref(:duo_core_add_on), ref(:self_hosted_dap_add_on)]
          end

          with_them do
            before do
              allow(project).to receive(:duo_foundational_flows_enabled).and_return(true)
              allow(::Ai::Catalog::FoundationalFlow).to receive(:[]).with('code_review/v1').and_return(nil)
              create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: add_on_type)
            end

            it "returns false for #{params[:add_on_type]}" do
              expect(subject).to be_falsey
            end
          end
        end

        context 'when duo_foundational_flows_enabled is true' do
          before do
            allow(project).to receive(:duo_foundational_flows_enabled).and_return(true)
          end

          context 'when code_review flow is not enabled' do
            where(:add_on_type) do
              [ref(:duo_core_add_on), ref(:self_hosted_dap_add_on)]
            end

            with_them do
              before do
                allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
              end

              it "returns false for #{params[:add_on_type]}" do
                expect(subject).to be_falsey
              end
            end
          end

          context 'when code_review flow is enabled' do
            before do
              allow(::Ai::Catalog::FoundationalFlow).to receive(:[])
                .with('code_review/v1')
                .and_return(
                  instance_double(::Ai::Catalog::FoundationalFlow, catalog_item: code_review_foundational_flow)
                )
              allow(project).to receive(:enabled_flow_catalog_item_ids).and_return([code_review_foundational_flow.id])
              allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
              create(:ai_catalog_enabled_foundational_flow, :for_project, project: project, catalog_item: code_review_foundational_flow)
            end

            where(:add_on_type) do
              [ref(:duo_core_add_on), ref(:self_hosted_dap_add_on)]
            end

            with_them do
              it "returns true for #{params[:add_on_type]}" do
                create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: add_on_type)

                expect(subject).to be_truthy
              end
            end

            context 'when instance has duo_enterprise add-on' do
              before do
                create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_enterprise_add_on)
              end

              it { is_expected.to be_truthy }
            end

            context 'when instance has expired duo_enterprise add-on' do
              before do
                # An expired add-on without gitlab_credits means StageCheck returns false;
                # override the parent stub that returns true for this context
                allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project,
                  :duo_workflow).and_return(false)
                create(:gitlab_subscription_add_on_purchase, :expired, :self_managed, add_on: duo_enterprise_add_on)
              end

              it { is_expected.to be_falsey }
            end

            context 'when StageCheck returns false' do
              where(:add_on_type) do
                [ref(:duo_core_add_on), ref(:self_hosted_dap_add_on)]
              end

              with_them do
                before do
                  allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(false)
                  create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: add_on_type)
                end

                it "returns false for #{params[:add_on_type]}" do
                  expect(subject).to be_falsey
                end
              end
            end

            context 'when StageCheck returns true' do
              where(:add_on_type) do
                [ref(:duo_core_add_on), ref(:self_hosted_dap_add_on)]
              end

              with_them do
                before do
                  allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
                  create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: add_on_type)
                end

                it "returns true for #{params[:add_on_type]}" do
                  expect(subject).to be_truthy
                end
              end
            end
          end
        end
      end
    end
  end

  describe '#container_scanning_for_registry_enabled' do
    context 'when security_setting exists' do
      context 'when container_scanning_for_registry_enabled is true' do
        let_it_be(:security_setting) { create(:project_security_setting, container_scanning_for_registry_enabled: true) }

        it 'returns true' do
          expect(security_setting.project.container_scanning_for_registry_enabled).to be true
        end
      end

      context 'when container_scanning_for_registry_enabled is false' do
        let_it_be(:security_setting) { create(:project_security_setting, container_scanning_for_registry_enabled: false) }

        it 'returns false' do
          expect(security_setting.project.container_scanning_for_registry_enabled).to be false
        end
      end
    end

    context 'when security_setting does not exist' do
      let_it_be(:project) { create(:project, name: 'project-without-security-setting') }

      before do
        project.security_setting.delete
      end

      it 'returns nil' do
        expect(project.reload.container_scanning_for_registry_enabled).to be_nil
      end
    end
  end

  describe '#has_container_registry_immutable_tag_rules?' do
    let_it_be_with_refind(:project) { create(:project) }

    subject { project.has_container_registry_immutable_tag_rules? }

    before_all do
      create(:container_registry_protection_tag_rule, project: project)
    end

    context 'when there is no immutable tag rule' do
      it { is_expected.to be false }
    end

    context 'when there is an immutable tag rule' do
      before_all do
        create(:container_registry_protection_tag_rule, :immutable, tag_name_pattern: 'immutable', project: project)
      end

      it { is_expected.to be true }
    end

    it 'memoizes calls with the same parameters' do
      allow(project.container_registry_protection_tag_rules).to receive(:immutable).and_call_original

      2.times do
        project.has_container_registry_immutable_tag_rules?
      end

      expect(project.container_registry_protection_tag_rules).to have_received(:immutable).once
    end
  end

  describe '#has_linked_configurations?' do
    let(:project) { build_stubbed(:project) }
    let(:assoc) { instance_double(ActiveRecord::Associations::Association) }
    let(:target) { double('target') }
    let(:scope) { double('scope') }
    let(:loaded) { true }

    before do
      allow(project)
        .to receive(:association)
        .with(:security_policy_management_project_linked_configurations)
        .and_return(assoc)

      allow(assoc).to receive(:loaded?).and_return(loaded)
      allow(assoc).to receive(:target).and_return(target)
      allow(assoc).to receive(:scope).and_return(scope)
      allow(scope).to receive(:exists?).and_return(true)
      allow(target).to receive(:any?).and_return(true)
    end

    context 'when the association is already loaded' do
      it 'calls #any? on the target' do
        expect(target).to receive(:any?)
        expect(scope).not_to receive(:exists?)

        project.has_linked_configurations?
      end
    end

    context 'when the association is not loaded' do
      let(:loaded) { false }

      it 'calls #exists? on the scope' do
        expect(scope).to receive(:exists?)
        expect(target).not_to receive(:any?)

        project.has_linked_configurations?
      end
    end
  end

  describe '.order_by_id_list' do
    let_it_be(:project1) { create(:project) }
    let_it_be(:project2) { create(:project) }
    let_it_be(:project3) { create(:project) }

    it 'orders projects by the given ID list order' do
      ids_in_custom_order = [project2.id, project3.id, project1.id]

      result = described_class.order_by_id_list(ids_in_custom_order)

      expect(result.map(&:id)).to eq(ids_in_custom_order)
    end

    it 'returns all records if ids are blank' do
      result = described_class.order_by_id_list([])

      expect(result).to match_array(described_class.all)
    end

    it 'returns all records if ids are nil' do
      result = described_class.order_by_id_list(nil)

      expect(result).to match_array(described_class.all)
    end
  end

  describe '#update_security_inventory_filters' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:inventory_filter) { create(:security_inventory_filters, project: project) }
    let(:old_name) { project.name }
    let(:new_name) { "New Project Name" }

    subject(:update_name) { project.update!(name: new_name) }

    it 'updates Security::InventoryFilter with new name' do
      expect { update_name }.to change { inventory_filter.reload.project_name }.from(old_name).to(new_name)
    end
  end

  describe '.public_or_visible_to_user' do
    let_it_be(:user) { create(:user) }
    let_it_be(:role) { create(:admin_member_role, :read_admin_projects, user: user) }

    let_it_be(:private_authorized_project) { create(:project, :private, creator: user) }
    let_it_be(:private_unauthorized_project) { create(:project, :private) } # project the user is not a member of
    let_it_be(:internal_project) { create(:project, :internal) }
    let_it_be(:public_project) { create(:project, :public) }

    subject(:projects) { described_class.all.public_or_visible_to_user(user) }

    before do
      stub_licensed_features(custom_roles: true)
      enable_admin_mode!(user)
    end

    it 'returns all projects' do
      expect(projects).to match_array(
        [private_authorized_project, private_unauthorized_project, internal_project, public_project]
      )
    end
  end

  shared_examples 'cascading project setting' do |settings_attribute:|
    let_it_be_with_refind(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    context 'with application setting enabled' do
      before do
        stub_application_setting(settings_attribute => true)
      end

      it 'inherits from application setting' do
        expect(project.send(settings_attribute)).to be_truthy
      end

      context 'when group overrides to false' do
        before do
          group.namespace_settings.update!(settings_attribute => false)
        end

        it 'uses group setting' do
          expect(project.reload.send(settings_attribute)).to be_falsey
        end
      end
    end

    context 'with cascading hierarchy' do
      let_it_be_with_refind(:parent_group) { create(:group) }
      let_it_be_with_refind(:child_group) { create(:group, parent: parent_group) }
      let_it_be(:project) { create(:project, group: child_group) }

      before do
        parent_group.namespace_settings.update!(settings_attribute => true)
      end

      it 'inherits from parent group' do
        expect(project.send(settings_attribute)).to be_truthy
      end

      context 'when child group overrides' do
        before do
          child_group.namespace_settings.update!(settings_attribute => false)
        end

        it 'uses child group setting' do
          expect(project.reload.send(settings_attribute)).to be_falsey
        end
      end
    end
  end

  describe '#auto_duo_code_review_enabled' do
    it_behaves_like 'cascading project setting', settings_attribute: :auto_duo_code_review_enabled
  end

  describe '#duo_remote_flows_enabled' do
    it_behaves_like 'cascading project setting', settings_attribute: :duo_remote_flows_enabled
  end

  describe '#duo_foundational_flows_enabled' do
    it_behaves_like 'cascading project setting', settings_attribute: :duo_foundational_flows_enabled
  end

  describe '#dap_powered_recommend_reviewers_available?' do
    let_it_be(:project) { create(:project) }

    let(:stage_check_available) { true }

    subject { project.dap_powered_recommend_reviewers_available? }

    before do
      project.project_setting.update!(duo_foundational_flows_enabled: true)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
        .with(project, :duo_workflow).and_return(stage_check_available)
    end

    context 'when the recommend_reviewers flow is enabled for the project' do
      before do
        item = create(:ai_catalog_item, :with_foundational_flow_reference,
          foundational_flow_reference: 'recommend_reviewers/v1')
        create(:ai_catalog_enabled_foundational_flow, :for_project, project: project, catalog_item: item)
      end

      it { is_expected.to be true }

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(dap_powered_recommend_reviewers: false)
        end

        it { is_expected.to be false }
      end

      context 'when duo_foundational_flows_enabled is false' do
        before do
          project.project_setting.update!(duo_foundational_flows_enabled: false)
        end

        it { is_expected.to be false }
      end

      context 'when StageCheck returns false' do
        let(:stage_check_available) { false }

        it { is_expected.to be false }
      end
    end

    context 'when the recommend_reviewers flow is not enabled for the project' do
      it { is_expected.to be false }
    end
  end

  describe '#foundational_flows_available?' do
    let_it_be(:namespace) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: namespace) }

    let(:stage_check_available) { true }

    subject { project.foundational_flows_available? }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
        .with(project, :foundational_flows).and_return(stage_check_available)
    end

    context 'when duo_foundational_flows_enabled is false' do
      before do
        project.project_setting.update!(duo_foundational_flows_enabled: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when duo_foundational_flows_enabled is true' do
      before do
        project.project_setting.update!(duo_foundational_flows_enabled: true)
      end

      context 'when StageCheck returns false' do
        let(:stage_check_available) { false }

        it { is_expected.to be(false) }
      end

      context 'when StageCheck returns true' do
        it { is_expected.to be(true) }
      end
    end
  end

  describe '#duo_dependency_bump_breaking_changes_available?' do
    let_it_be_with_reload(:project) { create(:project) }

    let(:stage_check_available) { true }

    subject { project.duo_dependency_bump_breaking_changes_available? }

    before do
      project.project_setting.update!(
        duo_dependency_bump_breaking_changes_enabled: true,
        duo_foundational_flows_enabled: true
      )
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
        .with(project, :foundational_flows).and_return(stage_check_available)
    end

    context 'when the resolve_dependency_bump flow is enabled for the project' do
      before do
        item = create(:ai_catalog_item, :with_foundational_flow_reference,
          foundational_flow_reference: 'resolve_dependency_bump/experimental')
        create(:ai_catalog_enabled_foundational_flow, :for_project, project: project, catalog_item: item)
      end

      it { is_expected.to be true }

      context 'when the project setting is disabled' do
        before do
          project.project_setting.update!(duo_dependency_bump_breaking_changes_enabled: false)
        end

        it { is_expected.to be false }
      end

      context 'when duo_foundational_flows_enabled is false' do
        before do
          project.project_setting.update!(duo_foundational_flows_enabled: false)
        end

        it { is_expected.to be false }
      end

      context 'when StageCheck returns false' do
        let(:stage_check_available) { false }

        it { is_expected.to be false }
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(enable_dependency_bump_breaking_changes: false)
        end

        it { is_expected.to be false }
      end
    end

    context 'when the resolve_dependency_bump flow is not enabled for the project' do
      it { is_expected.to be false }
    end
  end

  describe '#with_duo_features_enabled' do
    let_it_be(:p_on)  { create(:project, :with_duo_features_enabled) }
    let_it_be(:p_off) { create(:project, :with_duo_features_disabled) }

    it 'filters by project_settings.duo_features_enabled = true' do
      expect(described_class.with_duo_features_enabled).to contain_exactly(p_on)
    end
  end

  describe '.enabled_flow_catalog_item_ids' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project) { create(:project, group: namespace) }
    let_it_be(:catalog_item_1) { create(:ai_catalog_item, :with_foundational_flow_reference) }
    let_it_be(:catalog_item_2) { create(:ai_catalog_item, :with_foundational_flow_reference) }
    let_it_be(:catalog_item_3) { create(:ai_catalog_item, :with_foundational_flow_reference) }

    subject { project.enabled_flow_catalog_item_ids }

    context 'when project has no enabled foundational flows' do
      before do
        create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace, catalog_item: catalog_item_1)
        create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace, catalog_item: catalog_item_2)
      end

      it 'returns the namespace catalog item ids' do
        expect(subject).to match_array([catalog_item_1.id, catalog_item_2.id])
      end
    end

    context 'when project has enabled foundational flows' do
      before do
        create(:ai_catalog_enabled_foundational_flow, :for_project, project: project, catalog_item: catalog_item_1)
        create(:ai_catalog_enabled_foundational_flow, :for_project, project: project, catalog_item: catalog_item_2)
        create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace, catalog_item: catalog_item_3)
      end

      it 'returns the project catalog item ids' do
        expect(subject).to match_array([catalog_item_1.id, catalog_item_2.id])
      end
    end

    context 'when project has more than 100 enabled foundational flows' do
      before do
        allow(project.enabled_foundational_flow_records).to receive(:limit).with(100).and_return(
          project.enabled_foundational_flow_records.limit(3)
        )

        4.times do
          catalog_item = create(:ai_catalog_item, :with_foundational_flow_reference)
          create(:ai_catalog_enabled_foundational_flow, :for_project, project: project, catalog_item: catalog_item)
        end
      end

      it 'returns only the limit of catalog item ids' do
        expect(subject.size).to eq(3)
      end
    end
  end

  describe '#enabled_foundational_flow_references' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project) { create(:project, group: namespace) }
    let_it_be(:catalog_item_1) do
      create(:ai_catalog_item, :with_foundational_flow_reference, foundational_flow_reference: 'code_review/v1')
    end

    let_it_be(:catalog_item_2) do
      create(:ai_catalog_item, :with_foundational_flow_reference, foundational_flow_reference: 'bug_triage/v1')
    end

    subject { project.enabled_foundational_flow_references }

    context 'when duo foundational flows are disabled' do
      before do
        allow(project).to receive(:duo_foundational_flows_enabled).and_return(false)
        create(:ai_catalog_enabled_foundational_flow, :for_project, project: project, catalog_item: catalog_item_1)
      end

      it { is_expected.to eq([]) }
    end

    context 'when duo foundational flows are enabled' do
      before do
        allow(project).to receive(:duo_foundational_flows_enabled).and_return(true)
      end

      it 'returns the references of the enabled foundational flows' do
        create(:ai_catalog_enabled_foundational_flow, :for_project, project: project, catalog_item: catalog_item_1)
        create(:ai_catalog_enabled_foundational_flow, :for_project, project: project, catalog_item: catalog_item_2)

        expect(subject).to contain_exactly('code_review/v1', 'bug_triage/v1')
      end

      it 'returns an empty array when no foundational flows are enabled' do
        expect(subject).to eq([])
      end
    end
  end

  describe '#sync_enabled_foundational_flows!' do
    let_it_be(:project) { create(:project) }
    let_it_be(:flow1) { create(:ai_catalog_item, :with_foundational_flow_reference, :public, organization: project.organization) }
    let_it_be(:flow2) { create(:ai_catalog_item, :with_foundational_flow_reference, :public, organization: project.organization) }

    before do
      project.enabled_foundational_flow_records.delete_all
    end

    it 'creates enabled foundational flow records for given IDs' do
      project.sync_enabled_foundational_flows!([flow1.id, flow2.id])

      expect(project.enabled_foundational_flow_records.reload.pluck(:catalog_item_id)).to match_array([flow1.id, flow2.id])
    end

    it 'removes enabled foundational flow records not in target IDs' do
      create(:ai_catalog_enabled_foundational_flow, :for_project, project: project, catalog_item: flow1)
      create(:ai_catalog_enabled_foundational_flow, :for_project, project: project, catalog_item: flow2)

      project.sync_enabled_foundational_flows!([flow1.id])

      expect(project.enabled_foundational_flow_records.reload.pluck(:catalog_item_id)).to eq([flow1.id])
    end

    it 'deletes all records when target_ids is empty' do
      create(:ai_catalog_enabled_foundational_flow, :for_project, project: project, catalog_item: flow1)

      project.sync_enabled_foundational_flows!([])

      expect(project.enabled_foundational_flow_records.reload).to be_empty
    end

    it 'handles duplicates idempotently' do
      project.sync_enabled_foundational_flows!([flow1.id, flow2.id])

      expect { project.sync_enabled_foundational_flows!([flow1.id, flow2.id]) }
        .not_to change { project.enabled_foundational_flow_records.reload.count }
    end

    it 'tracks exceptions and raises when record is invalid' do
      allow(Ai::Catalog::EnabledFoundationalFlow).to receive(:bulk_insert!)
                                                       .and_raise(ActiveRecord::RecordInvalid.new(Ai::Catalog::EnabledFoundationalFlow.new))

      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
        instance_of(ActiveRecord::RecordInvalid),
        hash_including(project_id: project.id, target_ids: [flow1.id])
      )

      expect { project.sync_enabled_foundational_flows!([flow1.id]) }
        .to raise_error(RuntimeError, /Validation failed/)
    end
  end

  describe '#remove_foundational_flow_consumers' do
    let_it_be(:project) { create(:project) }
    let_it_be(:flow) { create(:ai_catalog_item, :with_foundational_flow_reference, :public, organization: project.organization) }
    let_it_be(:consumer) { create(:ai_catalog_item_consumer, project: project, item: flow) }

    it 'removes consumers for the given catalog item IDs' do
      expect { project.remove_foundational_flow_consumers([flow.id]) }
        .to change { project.configured_ai_catalog_items.count }.by(-1)
    end

    it 'does nothing when catalog_item_ids is empty' do
      expect { project.remove_foundational_flow_consumers([]) }
        .not_to change { project.configured_ai_catalog_items.count }
    end
  end

  describe '#security_scan_profile_for' do
    let_it_be(:project) { create(:project) }

    context 'when security_scan_profiles is not available' do
      before do
        stub_licensed_features(security_scan_profiles: false)
      end

      context 'when project has a secret_detection scan profile' do
        let_it_be(:secret_detection_profile) do
          create(:security_scan_profile,
            namespace: project.namespace,
            scan_type: :secret_detection,
            name: 'Secret Detection Profile')
        end

        let_it_be(:association) do
          create(:security_scan_profile_project, scan_profile: secret_detection_profile, project: project)
        end

        it 'returns nil' do
          expect(project.security_scan_profile_for(:secret_detection)).to be_nil
        end
      end
    end

    context 'when security_scan_profiles license is available' do
      before do
        stub_licensed_features(security_scan_profiles: true)
      end

      context 'when security_scan_profiles_feature is disabled' do
        before do
          stub_feature_flags(security_scan_profiles_feature: false)
        end

        context 'when project has a secret_detection scan profile' do
          let_it_be(:secret_detection_profile) do
            create(:security_scan_profile,
              namespace: project.namespace,
              scan_type: :secret_detection,
              name: 'Secret Detection Profile')
          end

          let_it_be(:association) do
            create(:security_scan_profile_project, scan_profile: secret_detection_profile, project: project)
          end

          it 'returns nil' do
            expect(project.security_scan_profile_for(:secret_detection)).to be_nil
          end
        end
      end

      context 'when project has a secret_detection scan profile' do
        let_it_be(:secret_detection_profile) do
          create(:security_scan_profile,
            namespace: project.namespace,
            scan_type: :secret_detection,
            name: 'Secret Detection Profile')
        end

        let_it_be(:association) do
          create(:security_scan_profile_project, scan_profile: secret_detection_profile, project: project)
        end

        it 'returns the relation for existing type' do
          result = project.security_scan_profile_for(:secret_detection)

          expect(result).to exist
        end

        it 'returns empty relation for non existing type' do
          result = project.security_scan_profile_for(:sast)

          expect(result).not_to be_nil
          expect(result).to be_empty
        end

        context 'when filtering by trigger_type' do
          let_it_be(:trigger) do
            create(:security_scan_profile_trigger,
              namespace: project.namespace,
              scan_profile: secret_detection_profile,
              trigger_type: :default_branch_pipeline)
          end

          it 'returns profiles with matching trigger type' do
            result = project.security_scan_profile_for(:secret_detection, :default_branch_pipeline)

            expect(result.first).to eq(secret_detection_profile)
          end

          it 'returns empty relation for non matching trigger type' do
            result = project.security_scan_profile_for(:secret_detection, :merge_request_pipeline)

            expect(result).not_to be_nil
            expect(result).to be_empty
          end

          it 'returns all profiles when trigger_type is nil' do
            result = project.security_scan_profile_for(:secret_detection, nil)

            expect(result).to exist
            expect(result.first).to eq(secret_detection_profile)
          end
        end
      end

      context 'when project has no scan profiles' do
        it 'returns empty relation' do
          result = project.security_scan_profile_for(:secret_detection)

          expect(result).not_to be_nil
          expect(result).to be_empty
        end
      end
    end
  end

  it_behaves_like 'a resource that has custom roles', :project

  context 'with approval policy queries', feature_category: :security_policy_management do
    let!(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let!(:security_policy) do
      create(:security_policy,
        security_orchestration_policy_configuration: policy_configuration,
        linked_projects: [project])
    end

    let!(:approval_policy_rule) do
      rule = create(:approval_policy_rule, :any_merge_request, security_policy: security_policy)
      create(:approval_policy_rule_project_link, project: project, approval_policy_rule: rule)
      rule
    end

    let!(:scan_result_policy_read) do
      create(:scan_result_policy_read, :targeting_commits,
        project: project,
        security_orchestration_policy_configuration: policy_configuration)
    end

    describe '#has_approval_policy_rules?' do
      context 'when flag is disabled' do
        before do
          stub_feature_flags(deprecate_scan_result_policies: false)
        end

        it 'checks scan_result_policy_reads' do
          expect(project.has_approval_policy_rules?).to be(true)
        end
      end

      it 'checks approval_policy_rules' do
        expect(project.has_approval_policy_rules?).to be(true)
      end

      context 'when only scan_result_policy_reads exist' do
        before do
          Security::ApprovalPolicyRuleProjectLink
            .where(approval_policy_rule: approval_policy_rule, project: project).delete_all
        end

        it 'falls back to scan_result_policy_reads' do
          expect(project.has_approval_policy_rules?).to be(true)
        end
      end
    end

    describe '#approval_policy_rules_targeting_commits?' do
      context 'when flag is disabled' do
        before do
          stub_feature_flags(deprecate_scan_result_policies: false)
        end

        it 'checks scan_result_policy_reads targeting commits' do
          expect(project.approval_policy_rules_targeting_commits?).to be(true)
        end
      end

      it 'checks approval_policy_rules targeting commits' do
        expect(project.approval_policy_rules_targeting_commits?).to be(true)
      end

      context 'when no approval_policy_rules target commits' do
        before do
          Security::ApprovalPolicyRuleProjectLink
            .where(approval_policy_rule: approval_policy_rule, project: project).delete_all
        end

        it 'falls back to scan_result_policy_reads targeting commits' do
          expect(project.approval_policy_rules_targeting_commits?).to be(true)
        end
      end
    end
  end
end
