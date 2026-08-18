#
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Project'], feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project, severity: :high) }

  let_it_be(:security_policy_management_project) { create(:project) }

  before do
    stub_licensed_features(security_dashboard: true, dependency_scanning: true)

    project.add_developer(user)
  end

  describe 'aiGovernanceMetrics' do
    it 'is priced so it cannot be fanned out across a projects connection' do
      # 200 is GitlabSchema::DEFAULT_MAX_COMPLEXITY, so 100 projects would cost
      # 1000 and be rejected before running 200 aggregate queries.
      expect(described_class.fields['aiGovernanceMetrics'].complexity).to eq(10)
    end
  end

  it 'includes the ee specific fields' do
    expected_fields = %w[
      security_training_providers vulnerabilities vulnerability_scanners requirement_states_count
      vulnerability_severities_count packages compliance_frameworks security_policies vulnerabilities_count_by_day
      security_dashboard_path iterations iteration_cadences repository_size_excess actual_repository_size_limit
      code_coverage_summary api_fuzzing_ci_configuration corpuses path_locks incident_management_escalation_policies
      incident_management_escalation_policy vulnerability_management_policies
      scan_execution_policies pipeline_execution_policies pipeline_execution_schedule_policies approval_policies
      security_policy_project security_training_urls vulnerability_images only_allow_merge_if_all_status_checks_passed
      security_policy_project_linked_projects security_policy_eligible_projects security_policy_project_linked_namespaces
      dependencies merge_requests_disable_committers_approval has_jira_vulnerability_issue_creation_enabled
      ci_upstream_project_subscriptions ci_downstream_project_subscriptions ci_subscriptions_projects ci_subscribed_projects
      ai_xray_reports duo_features_enabled components runner_cloud_provisioning
      google_cloud_artifact_registry_repository ai_metrics ai_usage_data ai_user_metrics saved_reply
      merge_trains pending_member_approvals observability_logs_links observability_metrics_links
      observability_traces_links dependencies security_exclusions security_exclusion
      compliance_standards_adherence target_branch_rules duo_workflow_status_check component_usages
      vulnerability_archives component_versions vulnerability_statistic analyzer_statuses
      compliance_requirement_statuses duo_agentic_chat_available container_scanning_for_registry_enabled duo_workflow_workflows
      duo_workflow_events security_metrics ai_catalog_item ai_catalog_item_consumer_for_item security_scan_profiles security_tracked_refs web_based_commit_signing_enabled
      merge_request_title_regex merge_request_title_regex_description dependency_tracked_refs
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe 'product analytics' do
    describe 'tracking_key' do
      where(
        :product_analytics_enabled,
        :project_instrumentation_key,
        :expected
      ) do
        false | nil | nil
        true  | 'snowplow-key' | 'snowplow-key'
        true  | nil | nil
      end

      with_them do
        let_it_be(:group) { create(:group) }
        let_it_be_with_reload(:project) { create(:project, group: group) }

        before do
          project.project_setting.update!(product_analytics_instrumentation_key: project_instrumentation_key)

          stub_application_setting(product_analytics_enabled: product_analytics_enabled)
          stub_licensed_features(product_analytics: product_analytics_enabled)
          stub_feature_flags(product_analytics_features: product_analytics_enabled)
        end

        let(:query) do
          %(
            query {
              project(fullPath: "#{project.full_path}") {
                trackingKey
              }
            }
          )
        end

        subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

        it 'returns the expected tracking_key' do
          tracking_key = subject.dig('data', 'project', 'trackingKey')
          expect(tracking_key).to eq(expected)
        end
      end
    end
  end

  describe 'secret push protection' do
    let_it_be(:security_setting) { create(:project_security_setting, secret_push_protection_enabled: true) }
    let_it_be_with_reload(:project) { security_setting.project }

    %w[secretPushProtectionEnabled preReceiveSecretDetectionEnabled].each do |field_name|
      describe field_name.underscore do
        where(:user_role, :licensed_feature, :expected) do
          :guest     | true  | nil
          :developer | true  | true
          :developer | false | nil
        end

        with_them do
          before do
            stub_licensed_features(secret_push_protection: licensed_feature)
            project.add_role(user, user_role)
          end

          let(:query) do
            %(
              query {
                project(fullPath: "#{project.full_path}") {
                  #{field_name}
                }
              }
            )
          end

          subject(:response) { GitlabSchema.execute(query, context: { current_user: user }).as_json }

          it "returns the expected value for #{field_name}" do
            value = response.dig('data', 'project', field_name)
            expect(value).to eq(expected)
          end
        end
      end
    end
  end

  describe 'container scanning for_registry enabled' do
    describe 'container_scanning_for_registry_enabled' do
      where(:enabled, :user_role, :expected) do
        true  | :guest     | nil
        true  | :developer | true
        false | :guest     | nil
        false | :developer | false
      end

      with_them do
        let!(:security_setting) { create(:project_security_setting, container_scanning_for_registry_enabled: enabled) }
        let!(:project) { security_setting.project }

        before do
          project.add_role(user, user_role)
        end

        let(:query) do
          %(
            query {
              project(fullPath: "#{project.full_path}") {
                containerScanningForRegistryEnabled
              }
            }
          )
        end

        subject(:response) { GitlabSchema.execute(query, context: { current_user: user }).as_json }

        it 'returns the expected container_scanning_for_registry_enabled value' do
          container_scanning_for_registry_enabled = response.dig('data', 'project', 'containerScanningForRegistryEnabled')
          expect(container_scanning_for_registry_enabled).to eq(expected)
        end
      end
    end
  end

  describe 'merge pipeline settings inherited from the parent group' do
    let(:group) { create(:group) }
    let(:user) { create(:user) }
    let(:project) do
      create(:project, group: group, only_allow_merge_if_pipeline_succeeds: false, allow_merge_on_skipped_pipeline: false)
    end

    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            onlyAllowMergeIfPipelineSucceeds
            allowMergeOnSkippedPipeline
          }
        }
      )
    end

    subject(:response) { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    before do
      stub_licensed_features(group_level_merge_checks_setting: true)
      group.namespace_settings.reload.update!(
        only_allow_merge_if_pipeline_succeeds: true,
        allow_merge_on_skipped_pipeline: true
      )
      project.add_maintainer(user)
    end

    it 'returns the effective values inherited from the group, not the raw project values' do
      data = response.dig('data', 'project')

      expect(data['onlyAllowMergeIfPipelineSucceeds']).to be(true)
      expect(data['allowMergeOnSkippedPipeline']).to be(true)
    end
  end

  describe 'security_scanners' do
    let_it_be_with_reload(:project) { create(:project, :repository) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project, sha: project.commit.id, ref: project.default_branch) }
    let_it_be(:user) { create(:user) }

    let_it_be(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            securityScanners {
              enabled
              available
              pipelineRun
            }
          }
        }
      )
    end

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    before do
      create(:ci_build, :success, :sast, name: "semgrep-sast", pipeline: pipeline)
      create(:ci_build, :success, :dast, pipeline: pipeline)
      create(:ci_build, :success, :license_scanning, pipeline: pipeline)
      create(:ci_build, :pending, :secret_detection, pipeline: pipeline)
    end

    it 'returns a list of analyzers enabled for the project' do
      query_result = subject.dig('data', 'project', 'securityScanners', 'enabled')
      expect(query_result).to match_array(%w[SAST DAST SECRET_DETECTION])
    end

    it 'returns a list of analyzers which were run in the last pipeline for the project' do
      query_result = subject.dig('data', 'project', 'securityScanners', 'pipelineRun')
      expect(query_result).to match_array(%w[DAST SAST])
    end
  end

  describe 'components' do
    subject(:components) do
      GitlabSchema.execute(query, context: { current_user: user })
        .as_json.dig(*%w[data project components])
    end

    let_it_be(:guest) { create(:user) }
    let_it_be(:developer) { create(:user) }

    let_it_be(:group) { create(:group, developers: developer, guests: guest) }
    let_it_be(:project_1) { create(:project, namespace: group) }
    let_it_be(:project_2) { create(:project, namespace: group) }

    let_it_be(:sbom_occurrence_1) { create(:sbom_occurrence, project: project_1) }
    let_it_be(:sbom_occurrence_2) { create(:sbom_occurrence, project: project_1) }
    let_it_be(:sbom_occurrence_3) { create(:sbom_occurrence, project: project_2) }

    let(:component_1) { sbom_occurrence_1.component }
    let(:component_2) { sbom_occurrence_2.component }
    let(:component_3) { sbom_occurrence_3.component }

    let(:filtered_query) { "components(name: \"#{component_name}\") { id name }" }
    let(:unfiltered_query) { 'components { id name }' }
    let(:query) do
      %(
        query {
          project(fullPath: "#{project_1.full_path}") {
            name
            #{components_query}
          }
        }
      )
    end

    before do
      stub_licensed_features(security_dashboard: true, dependency_scanning: true)
    end

    context 'with developer access' do
      let(:user) { developer }

      context 'when no name is passed' do
        let(:components_query) { unfiltered_query }

        it 'returns all components for all projects under given group' do
          names = components.pluck('name')

          expect(components.count).to be(2)
          expect(names).to match_array([component_1.name, component_2.name])
        end
      end

      context 'when name is passed' do
        let(:component_name) { component_1.name }
        let(:components_query) { filtered_query }

        it "returns all components that match the name" do
          expect(components.count).to be(1)
          expect(components.first['name']).to eq(component_1.name)
        end
      end
    end

    context 'without developer access' do
      let(:user) { guest }
      let(:components_query) { unfiltered_query }

      it { is_expected.to be_nil }
    end
  end

  describe 'dependencies' do
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:project) { create(:project, developers: user) }
    let_it_be(:sbom_occurrence_1) { create(:sbom_occurrence, project: project) }
    let_it_be(:sbom_occurrence_2) { create(:sbom_occurrence, project: project) }
    let_it_be(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            name
            dependencies {
              nodes {
                id
                name
              }
            }
          }
        }
      )
    end

    subject(:query_result) { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    it "returns all dependencies for all projects under given group" do
      dependencies = query_result.dig(*%w[data project dependencies nodes])

      expect(dependencies.count).to be(2)
      expect(dependencies.first['name']).to eq(sbom_occurrence_1.component_name)
      expect(dependencies.last['name']).to eq(sbom_occurrence_2.component_name)
    end
  end

  describe 'vulnerabilities' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:user) { create(:user) }
    let_it_be(:vulnerability) do
      create(:vulnerability, :detected, :critical, :with_finding, project: project, title: 'A terrible one!')
    end

    let_it_be(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            vulnerabilities {
              nodes {
                title
                severity
                state
              }
            }
          }
        }
      )
    end

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    it "returns the project's vulnerabilities" do
      vulnerabilities = subject.dig('data', 'project', 'vulnerabilities', 'nodes')

      expect(vulnerabilities.count).to be(1)
      expect(vulnerabilities.first['title']).to eq('A terrible one!')
      expect(vulnerabilities.first['state']).to eq('DETECTED')
      expect(vulnerabilities.first['severity']).to eq('CRITICAL')
    end
  end

  describe 'code coverage summary field' do
    subject { described_class.fields['codeCoverageSummary'] }

    it { is_expected.to have_graphql_type(Types::Ci::CodeCoverageSummaryType) }
  end

  describe 'merge_requests field' do
    subject { described_class.fields['mergeRequests'] }

    it { is_expected.to have_graphql_type(Types::MergeRequestType.connection_type) }
    it { is_expected.to have_graphql_resolver(Resolvers::ProjectMergeRequestsResolver) }

    it do
      is_expected.to include_graphql_arguments(
        :iids,
        :source_branches,
        :target_branches,
        :state,
        :draft,
        :labels,
        :label_name,
        :before,
        :after,
        :first,
        :last,
        :merged_after,
        :merged_before,
        :created_after,
        :created_before,
        :deployed_after,
        :deployed_before,
        :deployment_id,
        :updated_after,
        :updated_before,
        :author_username,
        :approved_by,
        :my_reaction_emoji,
        :merged_by,
        :release_tag,
        :assignee_username,
        :assignee_wildcard_id,
        :reviewer_username,
        :reviewer_wildcard_id,
        :review_state,
        :review_states,
        :milestone_title,
        :milestone_wildcard_id,
        :not,
        :sort,
        :approver
      )
    end
  end

  describe 'compliance_frameworks' do
    it 'queries in batches', :request_store, :use_clean_rails_memory_store_caching do
      projects = create_list(:project, 2, :with_compliance_framework)

      projects.each do |p|
        p.add_maintainer(user)
        # Cache warm up: runs authorization for each user.
        resolve_field(:id, p, current_user: user)
      end

      results = batch_sync(max_queries: 2) do
        projects.flat_map do |p|
          resolve_field(:compliance_frameworks, p, current_user: user)
        end
      end
      frameworks = results.flat_map(&:to_a)

      expect(frameworks).to match_array(projects.flat_map(&:compliance_management_frameworks))
    end

    describe 'compliance_frameworks authorization' do
      let_it_be(:group) { create(:group) }
      let_it_be_with_reload(:project) { create(:project, :with_compliance_framework, group: group) }
      let_it_be(:framework) { project.compliance_management_frameworks.first }
      let_it_be(:requirement) do
        create :compliance_requirement, framework: framework, name: 'Test Requirement', description: 'Sensitive data'
      end

      let(:query) do
        <<~GQL
        query {
          project(fullPath: "#{project.full_path}") {
            complianceFrameworks {
              nodes {
                id
                name
                description
                complianceRequirements {
                  nodes {
                    id
                    name
                    description
                  }
                }
              }
            }
          }
        }
        GQL
      end

      subject(:execute_query) do
        GitlabSchema.execute(query, context: { current_user: current_user }).as_json
      end

      shared_examples 'returning nil for compliance frameworks' do
        specify do
          result = execute_query.dig('data', 'project', 'complianceFrameworks')
          expect(result).to be_nil
        end
      end

      shared_examples 'returning compliance frameworks with requirements' do
        specify do
          frameworks = execute_query.dig('data', 'project', 'complianceFrameworks', 'nodes')
          expect(frameworks).not_to be_empty
          expect(frameworks.first['name']).to eq(framework.name)

          requirements = frameworks.first.dig('complianceRequirements', 'nodes')
          expect(requirements).not_to be_empty
          expect(requirements.first['name']).to eq('Test Requirement')
          expect(requirements.first['description']).to eq('Sensitive data')
        end
      end

      context 'when user is not a member' do
        let(:current_user) { create(:user) }

        it_behaves_like 'returning nil for compliance frameworks'
      end

      context 'when user is a guest' do
        let(:current_user) { create(:user) }

        before do
          project.add_guest(current_user)
        end

        it_behaves_like 'returning nil for compliance frameworks'
      end

      context 'when user is a reporter' do
        let(:current_user) { create(:user) }

        before do
          project.add_reporter(current_user)
        end

        it_behaves_like 'returning compliance frameworks with requirements'
      end

      context 'when user is a developer' do
        let(:current_user) { create(:user) }

        before do
          project.add_developer(current_user)
        end

        it_behaves_like 'returning compliance frameworks with requirements'

        context 'when security_and_compliance feature is disabled' do
          let(:current_user) { create(:user) }

          before do
            project.project_feature.update!(security_and_compliance_access_level: ProjectFeature::DISABLED)
          end

          it_behaves_like 'returning compliance frameworks with requirements'
        end
      end

      context 'when user is an auditor' do
        let(:current_user) { create(:user, :auditor) }

        it_behaves_like 'returning compliance frameworks with requirements'
      end

      context 'when user has custom role with read_vulnerability permission' do
        let(:current_user) { create(:user) }
        let(:member_role) { create(:member_role, :guest, namespace: group, read_vulnerability: true) }

        before do
          stub_licensed_features(custom_roles: true)
          create(:project_member, :guest, project: project, user: current_user, member_role: member_role)
        end

        it_behaves_like 'returning compliance frameworks with requirements'
      end

      context 'when user has custom role with read_dependency permission' do
        let(:current_user) { create(:user) }
        let(:member_role) { create(:member_role, :guest, namespace: group, read_dependency: true) }

        before do
          stub_licensed_features(custom_roles: true, dependency_scanning: true)
          create(:project_member, :guest, project: project, user: current_user, member_role: member_role)
        end

        it_behaves_like 'returning compliance frameworks with requirements'
      end

      context 'when user has custom role with manage_security_policy_link permission' do
        let(:current_user) { create(:user) }
        let(:member_role) { create(:member_role, :guest, namespace: group, manage_security_policy_link: true) }

        before do
          stub_licensed_features(custom_roles: true, security_orchestration_policies: true)
          create(:project_member, :guest, project: project, user: current_user, member_role: member_role)
        end

        it_behaves_like 'returning compliance frameworks with requirements'
      end
    end
  end

  describe 'compliance_standards_adherence' do
    let_it_be(:group) { create(:group) }
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            id
            name
            complianceStandardsAdherence {
              nodes {
                id
                status
              }
            }
          }
        }
      )
    end

    let_it_be_with_reload(:project) { create(:project, group: group) }
    let_it_be(:adherence_1) do
      create(:compliance_standards_adherence, project: project, check_name: :prevent_approval_by_merge_request_author)
    end

    let_it_be(:adherence_2) do
      create(:compliance_standards_adherence, project: project, check_name: :prevent_approval_by_merge_request_committers)
    end

    before do
      project.add_owner(user)
      stub_licensed_features(project_level_compliance_adherence_report: true)
    end

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    it 'returns associated standard adherence statuses' do
      adherence = subject.dig('data', 'project', 'complianceStandardsAdherence', 'nodes')

      expect(adherence.count).to eq(2)
    end
  end

  describe 'vulnerability_identifier_search' do
    let_it_be(:identifier) { create(:vulnerabilities_identifier, project: project, external_type: 'cwe', name: 'CWE-23') }

    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            vulnerabilityIdentifierSearch(name: "cwe") {
            }
          }
        }
      )
    end

    let(:current_user) { user }

    subject(:search_results) do
      GitlabSchema.execute(query, context: { current_user:
        current_user }).as_json
    end

    context 'when the user has access' do
      it 'returns the matching search result' do
        results = search_results.dig('data', 'project', 'vulnerabilityIdentifierSearch')
        expect(results).to contain_exactly(identifier.name)
      end
    end

    context 'when user do not have access' do
      let(:current_user) { create(:user) }

      it 'returns nil' do
        results = search_results.dig('data', 'project', 'vulnerabilityIdentifierSearch')
        expect(results).to be_nil
      end
    end
  end

  describe 'analyzer_statuses' do
    let_it_be_with_reload(:project) { create(:project, :with_analyzer_statuses) }
    let_it_be(:user) { create(:user) }

    where(:user_role, :licensed_feature, :data_expected) do
      :guest      | false | false
      :guest      | true  | false
      :developer  | false | false
      :developer  | true  | true
      :reporter   | false | false
      :reporter   | true  | false
      :maintainer | false | false
      :maintainer | true  | true
      :owner      | false | false
      :owner      | true  | true
    end

    with_them do
      let(:query) do
        <<~GQL
          query {
            project(fullPath: "#{project.full_path}") {
              analyzerStatuses {
                status
                analyzerType
              }
            }
          }
        GQL
      end

      before do
        stub_licensed_features(security_inventory: licensed_feature)
        project.add_role(user, user_role)
      end

      subject(:search_results) do
        GitlabSchema.execute(query, context: { current_user: user }).as_json
      end

      it 'returns data only when expected' do
        results = search_results.dig('data', 'project', 'analyzerStatuses')
        expect(results.present?).to be(data_expected)
      end
    end
  end

  describe 'vulnerability_statistic' do
    subject(:search_results) do
      GitlabSchema.execute(query, context: { current_user: user }).as_json
    end

    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, :with_vulnerability_statistic, group: group) }
    let_it_be(:user) { create(:user) }

    let(:query) do
      <<~GQL
        query {
          project(fullPath: "#{project.full_path}") {
            vulnerabilityStatistic {
              updatedAt
            }
          }
        }
      GQL
    end

    before do
      group.add_maintainer(user)
    end

    context 'when feature is available' do
      it 'returns data' do
        stub_licensed_features(security_inventory: true)

        results = search_results.dig('data', 'project', 'vulnerabilityStatistic')
        expect(results.present?).to be(true)
      end
    end

    context 'when feature is not available' do
      it 'returns nil' do
        stub_licensed_features(security_inventory: false)

        results = search_results.dig('data', 'project', 'vulnerabilityStatistic')
        expect(results).to be_nil
      end
    end
  end

  describe 'push rules field' do
    subject { described_class.fields['pushRules'] }

    it { is_expected.to have_graphql_type(Types::PushRulesType) }
  end

  shared_context 'is an orchestration policy' do
    let(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project, security_policy_management_project: security_policy_management_project) }
    let(:policy_yaml) { Gitlab::Config::Loader::Yaml.new(fixture_file('security_orchestration.yml', dir: 'ee')).load! }

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    before do
      allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |policy|
        allow(policy).to receive(:policy_configuration_valid?).and_return(true)
        allow(policy).to receive(:policy_hash).and_return(policy_yaml)
        allow(policy).to receive(:policy_last_updated_at).and_return(Time.now)
      end

      stub_licensed_features(security_orchestration_policies: true)
      policy_configuration.security_policy_management_project.add_maintainer(user)
    end
  end

  describe 'scan_execution_policies', feature_category: :security_policy_management do
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            scanExecutionPolicies {
              nodes {
                name
                description
                enabled
                yaml
                updatedAt
              }
            }
          }
        }
      )
    end

    include_context 'is an orchestration policy'

    it 'returns associated scan execution policies' do
      policies = subject.dig('data', 'project', 'scanExecutionPolicies', 'nodes')

      expect(policies.count).to be(8)
    end

    describe 'scopes' do
      let(:field) { described_class.fields['scanExecutionPolicies'] }

      subject { field.scopes }

      it { is_expected.to include(:ai_workflows) }
    end
  end

  describe 'scan_result_policies', feature_category: :security_policy_management do
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            scanResultPolicies {
              nodes {
                name
                description
                enabled
                yaml
                updatedAt
              }
            }
          }
        }
      )
    end

    include_context 'is an orchestration policy'

    it 'returns associated scan result policies' do
      policies = subject.dig('data', 'project', 'scanResultPolicies', 'nodes')

      expect(policies.count).to be(8)
    end
  end

  describe 'approval_policies', feature_category: :security_policy_management do
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            approvalPolicies {
              nodes {
                name
                description
                enabled
                yaml
                updatedAt
              }
            }
          }
        }
      )
    end

    include_context 'is an orchestration policy'

    it 'returns associated approval policies' do
      policies = subject.dig('data', 'project', 'approvalPolicies', 'nodes')

      expect(policies.count).to be(8)
    end
  end

  describe 'pipeline_execution_policies', feature_category: :security_policy_management do
    let_it_be(:ref_project) { create(:project, :repository) }
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            pipelineExecutionPolicies {
              nodes {
                name
                description
                enabled
                yaml
                updatedAt
              }
            }
          }
        }
      )
    end

    before do
      allow(Project).to receive(:find_by_full_path).and_return(ref_project)
    end

    include_context 'is an orchestration policy'

    it 'returns associated approval policies' do
      policies = subject.dig('data', 'project', 'pipelineExecutionPolicies', 'nodes')

      expect(policies.count).to be(7)
    end
  end

  describe 'security_policy_project', feature_category: :security_policy_management do
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            securityPolicyProject {
              name
              fullPath
            }
          }
        }
      )
    end

    include_context 'is an orchestration policy'

    it 'returns the associated security policy project' do
      result = subject.dig('data', 'project', 'securityPolicyProject')

      expect(result).to eq(
        'name' => security_policy_management_project.name,
        'fullPath' => security_policy_management_project.full_path
      )
    end
  end

  describe 'security_policy_project_linked_projects', feature_category: :security_policy_management do
    let(:query) do
      %(
        query {
          project(fullPath: "#{security_policy_management_project.full_path}") {
            securityPolicyProjectLinkedProjects {
              nodes {
                name
                fullPath
              }
            }
          }
        }
      )
    end

    include_context 'is an orchestration policy'

    it 'returns the associated security policy project' do
      result = subject.dig('data', 'project', 'securityPolicyProjectLinkedProjects', 'nodes', 0)

      expect(result).to eq(
        'name' => project.name,
        'fullPath' => project.full_path
      )
    end
  end

  describe 'security_policy_project_linked_namespaces', feature_category: :security_policy_management do
    let(:policy_configuration) { create(:security_orchestration_policy_configuration, :namespace, namespace: namespace, security_policy_management_project: security_policy_management_project) }
    let(:query) do
      %(
        query {
          project(fullPath: "#{security_policy_management_project.full_path}") {
            securityPolicyProjectLinkedNamespaces {
              nodes {
                name
                fullPath
              }
            }
          }
        }
      )
    end

    let(:policy_yaml) { Gitlab::Config::Loader::Yaml.new(fixture_file('security_orchestration.yml', dir: 'ee')).load! }

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    before do
      allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |policy|
        allow(policy).to receive(:policy_configuration_valid?).and_return(true)
        allow(policy).to receive(:policy_hash).and_return(policy_yaml)
        allow(policy).to receive(:policy_last_updated_at).and_return(Time.now)
      end

      stub_licensed_features(security_orchestration_policies: true)
      policy_configuration.security_policy_management_project.add_maintainer(user)
      namespace.add_developer(user)
    end

    it 'returns the associated security policy project' do
      result = subject.dig('data', 'project', 'securityPolicyProjectLinkedNamespaces', 'nodes', 0)

      expect(result).to eq(
        'name' => namespace.name,
        'fullPath' => namespace.full_path
      )
    end
  end

  describe 'security_policy_project_linked_groups', feature_category: :security_policy_management do
    let(:policy_configuration) { create(:security_orchestration_policy_configuration, :namespace, namespace: namespace, security_policy_management_project: security_policy_management_project) }
    let(:query) do
      %(
        query {
          project(fullPath: "#{security_policy_management_project.full_path}") {
            securityPolicyProjectLinkedGroups {
              nodes {
                name
                fullPath
              }
            }
          }
        }
      )
    end

    let(:policy_yaml) { Gitlab::Config::Loader::Yaml.new(fixture_file('security_orchestration.yml', dir: 'ee')).load! }

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    before do
      allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |policy|
        allow(policy).to receive(:policy_configuration_valid?).and_return(true)
        allow(policy).to receive(:policy_hash).and_return(policy_yaml)
        allow(policy).to receive(:policy_last_updated_at).and_return(Time.now)
      end

      stub_licensed_features(security_orchestration_policies: true)
      policy_configuration.security_policy_management_project.add_maintainer(user)
      namespace.add_developer(user)
    end

    it 'returns the associated security policy project' do
      result = subject.dig('data', 'project', 'securityPolicyProjectLinkedGroups', 'nodes', 0)

      expect(result).to eq(
        'name' => namespace.name,
        'fullPath' => namespace.full_path
      )
    end
  end

  describe 'security_scan_profiles', feature_category: :security_testing_configuration do
    describe 'scopes' do
      let(:field) { described_class.fields['securityScanProfiles'] }

      subject { field.scopes }

      it { is_expected.to include(:ai_workflows) }
    end
  end

  describe 'dora field' do
    subject { described_class.fields['dora'] }

    it { is_expected.to have_graphql_type(::Types::Analytics::Dora::DoraType) }
  end

  describe 'vulnerability_images' do
    let_it_be(:vulnerability) { create(:vulnerability, project: project, report_type: :cluster_image_scanning) }
    let_it_be(:finding) do
      create(
        :vulnerabilities_finding,
        :with_cluster_image_scanning_scanning_metadata,
        project: project,
        vulnerability: vulnerability
      )
    end

    let_it_be(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            vulnerabilityImages {
              nodes {
                name
              }
            }
          }
        }
      )
    end

    subject(:vulnerability_images) do
      result = GitlabSchema.execute(query, context: { current_user: current_user }).as_json
      result.dig('data', 'project', 'vulnerabilityImages', 'nodes', 0)
    end

    context 'when user is not logged in' do
      let(:current_user) { nil }

      it { is_expected.to be_nil }
    end

    context 'when user is logged in' do
      let(:current_user) { user }

      it 'returns a list of container images reported for vulnerabilities' do
        expect(vulnerability_images).to eq('name' => 'alpine:3.7')
      end
    end
  end

  describe 'has_jira_vulnerability_issue_creation_enabled' do
    let_it_be(:jira_integration) { create(:jira_integration, project: project) }

    let_it_be(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            hasJiraVulnerabilityIssueCreationEnabled
          }
        }
      )
    end

    subject(:has_jira_vulnerability_issue_creation_enabled) do
      result = GitlabSchema.execute(query, context: { current_user: user }).as_json
      result.dig('data', 'project', 'hasJiraVulnerabilityIssueCreationEnabled')
    end

    context 'when jira integration is enabled' do
      before do
        allow_next_found_instance_of(::Integrations::Jira) do |jira_integration|
          allow(jira_integration).to receive(:configured_to_create_issues_from_vulnerabilities?).and_return(true)
        end
      end

      it 'returns true' do
        expect(has_jira_vulnerability_issue_creation_enabled).to be true
      end
    end

    context 'when jira integration is not enabled' do
      before do
        allow_next_found_instance_of(::Integrations::Jira) do |jira_integration|
          allow(jira_integration).to receive(:configured_to_create_issues_from_vulnerabilities?).and_return(false)
        end
      end

      it 'returns false' do
        expect(has_jira_vulnerability_issue_creation_enabled).to be false
      end
    end
  end

  describe 'runnerCloudProvisioning', feature_category: :runner_core do
    subject { described_class.fields['runnerCloudProvisioning'] }

    it { is_expected.to have_graphql_type(::Types::Ci::RunnerCloudProvisioningType) }
  end

  describe 'component_versions' do
    subject { described_class.fields['componentVersions'] }

    it { is_expected.to have_non_null_graphql_type(Types::Sbom::ComponentVersionType.connection_type) }
    it { is_expected.to have_graphql_resolver(::Resolvers::Sbom::ComponentVersionResolver) }

    it { is_expected.to include_graphql_arguments(:component_name) }
  end

  describe 'container_protection_tag_rules' do
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            containerProtectionTagRules {
              nodes {
                id
                tagNamePattern
                minimumAccessLevelForPush
                minimumAccessLevelForDelete
              }
            }
          }
        }
      )
    end

    before_all do
      create(:container_registry_protection_tag_rule, :immutable,
        project: project,
        tag_name_pattern: 'immutable-1'
      )

      create(:container_registry_protection_tag_rule,
        project: project,
        minimum_access_level_for_push: Gitlab::Access::MAINTAINER,
        minimum_access_level_for_delete: Gitlab::Access::OWNER,
        tag_name_pattern: 'mutable'
      )

      create(:container_registry_protection_tag_rule, :immutable,
        project: project,
        tag_name_pattern: 'immutable-2'
      )
    end

    before do
      project.add_maintainer(user)
    end

    subject do
      GitlabSchema.execute(query, context: { current_user: user }).as_json
        .dig('data', 'project', 'containerProtectionTagRules', 'nodes')
    end

    context 'when license for container_registry_immutable_tag_rules is disabled' do
      it { is_expected.to have_attributes(size: 1).and satisfy { |nodes| nodes.first['tagNamePattern'] == 'mutable' } }
    end

    context 'when license for container_registry_immutable_tag_rules is enabled' do
      before do
        stub_licensed_features(container_registry_immutable_tag_rules: true)
      end

      it { is_expected.to have_attributes(size: 3).and satisfy { |nodes| nodes.first['tagNamePattern'] == 'mutable' } }
    end
  end

  describe 'security_policy_pipeline_must_succeed', feature_category: :security_policy_management do
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            securityPolicyPipelineMustSucceed
          }
        }
      )
    end

    subject(:result) do
      GitlabSchema.execute(query, context: { current_user: user }).dig('data', 'project', 'securityPolicyPipelineMustSucceed')
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(security_policy_pipeline_check: false)
        stub_licensed_features(security_orchestration_policies: true)
      end

      it { is_expected.to be_nil }
    end

    context 'when license is not available' do
      before do
        stub_feature_flags(security_policy_pipeline_check: true)
        stub_licensed_features(security_orchestration_policies: false)
      end

      it { is_expected.to be_nil }
    end

    context 'when feature flag and license are available' do
      before do
        stub_feature_flags(security_policy_pipeline_check: true)
        stub_licensed_features(security_orchestration_policies: true)
        project.project_setting.update!(security_policy_pipeline_must_succeed: true)
      end

      it { is_expected.to be(true) }
    end
  end

  describe 'duo_workflow_workflows field' do
    subject { described_class.fields['duoWorkflowWorkflows'] }

    it { is_expected.to have_graphql_type(Types::Ai::DuoWorkflows::WorkflowType.connection_type) }
    it { is_expected.to have_graphql_resolver(Resolvers::Ai::DuoWorkflows::WorkflowsResolver) }
    it { is_expected.to have_graphql_arguments(:project_path, :sort, :type, :workflow_id, :environment, :exclude_types, :search, :status_group, :updated_after, :ids) }
  end

  describe 'duo_workflow_events field' do
    subject { described_class.fields['duoWorkflowEvents'] }

    it { is_expected.to have_graphql_type(Types::Ai::DuoWorkflows::WorkflowEventType.connection_type) }
    it { is_expected.to have_graphql_resolver(Resolvers::Ai::DuoWorkflows::WorkflowEventsResolver) }
    it { is_expected.to have_graphql_arguments(:workflow_id) }
  end

  describe 'duo_workflow_status_check field' do
    subject { described_class.fields['duoWorkflowStatusCheck'] }

    it { is_expected.to have_graphql_type(Types::Ai::DuoWorkflows::EnablementType) }

    describe 'scopes' do
      subject { described_class.fields['duoWorkflowStatusCheck'].scopes }

      it { is_expected.to match_array([:api, :read_api, :ai_workflows]) }
    end
  end

  describe 'vulnerability_workflow_execution' do
    let(:query) do
      <<~GQL
      query {
        project(fullPath: "#{project.full_path}") {
          vulnerabilityWorkflowExecution(
            workflow: RESOLVE_SAST_VULNERABILITY_V1
          ) {
            executionId
            status
          }
        }
      }
      GQL
    end

    subject(:response) do
      GitlabSchema.execute(query, context: { current_user: current_user }).as_json
    end

    context 'when the user has permission' do
      let(:current_user) { create(:user) }

      before do
        project.add_maintainer(current_user)

        Vulnerabilities::BulkDuoWorkflow::ExecutionState.create!(
          project_id: project.id,
          workflow: ::Vulnerabilities::TriggerResolutionWorkflowWorker::WORKFLOW_DEFINITION,
          stages: [
            { name: 'critical', order: 0 }
          ]
        )
      end

      it 'returns the execution' do
        execution = response.dig('data', 'project', 'vulnerabilityWorkflowExecution')

        expect(response['errors']).to be_nil
        expect(execution).to include(
          'executionId',
          'status' => 'CREATED'
        )
      end
    end

    context 'when the user does not have permission' do
      let(:current_user) { create(:user) }

      before do
        project.add_developer(current_user)
      end

      it 'returns nil' do
        expect(response.dig('data', 'project', 'vulnerabilityWorkflowExecution')).to be_nil
      end
    end
  end
end
