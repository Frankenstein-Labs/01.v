# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Group'], feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax

  describe 'nested epic request' do
    it { expect(described_class).to have_graphql_field(:epicsEnabled) }
    it { expect(described_class).to have_graphql_field(:epic) }
    it { expect(described_class).to have_graphql_field(:epics) }
    it { expect(described_class).to have_graphql_field(:epic_board) }
    it { expect(described_class).to have_graphql_field(:epic_boards) }
  end

  describe 'aiGovernanceMetrics' do
    it 'is priced so it cannot be fanned out across a projects connection' do
      # 200 is GitlabSchema::DEFAULT_MAX_COMPLEXITY, so 100 projects would cost
      # 1000 and be rejected before running 200 aggregate queries.
      expect(described_class.fields['aiGovernanceMetrics'].complexity).to eq(10)
    end
  end

  it { expect(described_class).to have_graphql_field(:iterations) }
  it { expect(described_class).to have_graphql_field(:iteration_cadences) }
  it { expect(described_class).to have_graphql_field(:vulnerabilities) }
  it { expect(described_class).to have_graphql_field(:vulnerability_scanners) }
  it { expect(described_class).to have_graphql_field(:vulnerability_namespace_statistic) }
  it { expect(described_class).to have_graphql_field(:vulnerability_severities_count) }
  it { expect(described_class).to have_graphql_field(:vulnerabilities_count_by_day) }
  it { expect(described_class).to have_graphql_field(:vulnerability_grades) }
  it { expect(described_class).to have_graphql_field(:analyzer_statuses) }
  it { expect(described_class).to have_graphql_field(:code_coverage_activities) }
  it { expect(described_class).to have_graphql_field(:stats) }
  it { expect(described_class).to have_graphql_field(:billable_members_count) }
  it { expect(described_class).to have_graphql_field(:external_audit_event_destinations) }
  it { expect(described_class).to have_graphql_field(:external_audit_event_streaming_destinations) }
  it { expect(described_class).to have_graphql_field(:google_cloud_logging_configurations) }
  it { expect(described_class).to have_graphql_field(:merge_request_violations) }
  it { expect(described_class).to have_graphql_field(:allow_stale_runner_pruning) }
  it { expect(described_class).to have_graphql_field(:cluster_agents) }
  it { expect(described_class).to have_graphql_field(:enforce_free_user_cap) }
  it { expect(described_class).to have_graphql_field(:project_compliance_standards_adherence) }
  it { expect(described_class).to have_graphql_field(:amazon_s3_configurations) }
  it { expect(described_class).to have_graphql_field(:member_roles) }
  it { expect(described_class).to have_graphql_field(:standard_role) }
  it { expect(described_class).to have_graphql_field(:standard_roles) }
  it { expect(described_class).to have_graphql_field(:pending_members) }
  it { expect(described_class).to have_graphql_field(:value_streams) }
  it { expect(described_class).to have_graphql_field(:saved_replies) }
  it { expect(described_class).to have_graphql_field(:saved_reply) }
  it { expect(described_class).to have_graphql_field(:value_stream_analytics) }
  it { expect(described_class).to have_graphql_field(:duo_features_enabled) }
  it { expect(described_class).to have_graphql_field(:lock_duo_features_enabled) }
  it { expect(described_class).to have_graphql_field(:duo_settings_path) }
  it { expect(described_class).to have_graphql_field(:ai_metrics) }
  it { expect(described_class).to have_graphql_field(:ai_usage_data) }
  it { expect(described_class).to have_graphql_field(:ai_user_metrics) }
  it { expect(described_class).to have_graphql_field(:pending_member_approvals) }
  it { expect(described_class).to have_graphql_field(:compliance_framework_coverage_summary) }
  it { expect(described_class).to have_graphql_field(:dependencies) }
  it { expect(described_class).to have_graphql_field(:components) }
  it { expect(described_class).to have_graphql_field(:custom_fields) }
  it { expect(described_class).to have_graphql_field(:compliance_requirement_coverage) }
  it { expect(described_class).to have_graphql_field(:project_compliance_requirements_status) }
  it { expect(described_class).to have_graphql_field(:component_versions) }
  it { expect(described_class).to have_graphql_field(:compliance_requirement_control_coverage) }
  it { expect(described_class).to have_graphql_field(:virtual_registries_packages_maven_registries) }
  it { expect(described_class).to have_graphql_field(:virtual_registries_container_registries) }
  it { expect(described_class).to have_graphql_field(:security_metrics) }
  it { expect(described_class).to have_graphql_field(:project_compliance_violations) }
  it { expect(described_class).to have_graphql_field(:compliance_frameworks_needing_attention) }
  it { expect(described_class).to have_graphql_field(:web_based_commit_signing_enabled) }
  it { expect(described_class).to have_graphql_field(:ai_audit_events_storage_enabled) }
  it { expect(described_class).to have_graphql_field(:lock_ai_audit_events_storage_enabled) }
  it { expect(described_class).to have_graphql_field(:virtual_registries_packages_maven_upstreams) }
  it { expect(described_class).to have_graphql_field(:virtual_registries_container_upstreams) }
  it { expect(described_class).to have_graphql_field(:virtual_registries_cleanup_policy) }
  it { expect(described_class).to have_graphql_field(:webhook) }
  it { expect(described_class).to have_graphql_field(:knowledge_graph_enabled) }
  it { expect(described_class).to have_graphql_field(:knowledge_graph_available) }
  it { expect(described_class).to have_graphql_field(:built_in_project_templates_enabled) }
  it { expect(described_class).to have_graphql_field(:lock_built_in_project_templates_enabled) }

  describe 'components' do
    let_it_be(:guest) { create(:user) }
    let_it_be(:developer) { create(:user) }
    let_it_be(:group) { create(:group, developers: developer, guests: guest) }
    let_it_be(:project_1) { create(:project, namespace: group) }
    let_it_be(:sbom_occurrence_1) { create(:sbom_occurrence, project: project_1) }
    let(:component_1) { sbom_occurrence_1.component }
    let_it_be(:project_2) { create(:project, namespace: group) }
    let_it_be(:sbom_occurrence_2) { create(:sbom_occurrence, project: project_2) }
    let(:component_2) { sbom_occurrence_2.component }
    let(:query) do
      %(
        query {
          group(fullPath: "#{group.full_path}") {
            name
            #{components_query}
              id
              name
            }
          }
        }
      )
    end

    let(:components_query) do
      if component_name
        "components(name: \"#{component_name}\") {"
      else
        "components {"
      end
    end

    subject(:query_result) { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    before do
      stub_licensed_features(security_dashboard: true, dependency_scanning: true)
    end

    context 'with developer access' do
      let(:user) { developer }

      context 'when no name is passed' do
        let(:component_name) { nil }

        it 'returns all components for all projects under given group' do
          components = query_result.dig(*%w[data group components])
          names = components.pluck('name')

          expect(components.count).to be(2)
          expect(names).to match_array([component_1.name, component_2.name])
        end
      end

      context 'when name is passed' do
        let(:component_name) { component_2.name }

        it "returns all components that match the name" do
          components = query_result.dig(*%w[data group components])

          expect(components.count).to be(1)
          expect(components.first['name']).to eq(component_2.name)
        end
      end
    end

    context 'without developer access' do
      let(:user) { guest }
      let(:component_name) { component_2.name }

      it 'does not return any components' do
        components = query_result.dig(*%w[data group components])
        expect(components).to be_nil
      end
    end
  end

  describe 'dependencies' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, developers: user) }
    let_it_be(:project_1) { create(:project, namespace: group) }
    let_it_be(:sbom_occurrence_1) { create(:sbom_occurrence, project: project_1) }
    let_it_be(:project_2) { create(:project, namespace: group) }
    let_it_be(:sbom_occurrence_2) { create(:sbom_occurrence, project: project_2) }
    let_it_be(:query) do
      %(
        query {
          group(fullPath: "#{group.full_path}") {
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

    before do
      stub_licensed_features(security_dashboard: true, dependency_scanning: true)
    end

    it "returns all dependencies for all projects under given group" do
      dependencies = query_result.dig(*%w[data group dependencies nodes])

      expect(dependencies.count).to be(2)
      expect(dependencies.first['name']).to eq(sbom_occurrence_1.component_name)
      expect(dependencies.last['name']).to eq(sbom_occurrence_2.component_name)
    end
  end

  describe 'vulnerabilities' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:user) { create(:user) }
    let_it_be(:vulnerability) do
      create(:vulnerability, :detected, :critical, :with_read, project: project, title: 'A terrible one!')
    end

    let_it_be(:query) do
      %(
        query {
          group(fullPath: "#{group.full_path}") {
            name
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

    before do
      stub_licensed_features(security_dashboard: true)

      group.add_developer(user)
    end

    subject(:results) { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    it "returns the vulnerabilities for all projects in the group and its subgroups" do
      vulnerabilities = results.dig('data', 'group', 'vulnerabilities', 'nodes')

      expect(vulnerabilities.count).to be(1)
      expect(vulnerabilities.first['title']).to eq('A terrible one!')
      expect(vulnerabilities.first['state']).to eq('DETECTED')
      expect(vulnerabilities.first['severity']).to eq('CRITICAL')
    end
  end

  describe 'vulnerability_identifier_search' do
    subject(:search_results) do
      GitlabSchema.execute(query, context: { current_user: current_user }).as_json
    end

    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:user) { create(:user) }
    let_it_be(:other_user) { create(:user) }

    let_it_be(:identifier) do
      create(:vulnerabilities_identifier, project: project, external_type: 'cwe', name: 'CWE-23')
    end

    let_it_be(:vulnerability_statistic) do
      create(:vulnerability_statistic, project: project)
    end

    let(:query) do
      %(
        query {
          group(fullPath: "#{group.full_path}") {
            vulnerabilityIdentifierSearch(name: "cwe") {
            }
          }
        }
      )
    end

    before do
      stub_licensed_features(security_dashboard: true, dependency_scanning: true)
      group.add_developer(user)
    end

    context 'when the user has access' do
      let(:current_user) { user }

      it 'returns the matching search result' do
        results = search_results.dig('data', 'group', 'vulnerabilityIdentifierSearch')
        expect(results).to contain_exactly(identifier.name)
      end
    end

    context 'when user do not have access' do
      let(:current_user) { other_user }

      it 'returns nil' do
        results = search_results.dig('data', 'group', 'vulnerabilityIdentifierSearch')
        expect(results).to be_nil
      end
    end
  end

  describe 'vulnerability_namespace_statistic' do
    subject(:search_results) do
      GitlabSchema.execute(query, context: { current_user: user }).as_json
    end

    let_it_be(:group) { create(:group) }
    let_it_be(:user) { create(:user) }

    let(:query) do
      <<~GQL
        query {
          group(fullPath: "#{group.full_path}") {
            vulnerabilityNamespaceStatistic {
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
        stub_licensed_features(security_inventory: true, security_dashboard: true)

        results = search_results.dig('data', 'group', 'vulnerabilityNamespaceStatistic')
        expect(results.present?).to be(true)
      end
    end

    context 'when feature is not available' do
      it 'returns nil' do
        stub_licensed_features(security_inventory: false)

        results = search_results.dig('data', 'group', 'vulnerabilityNamespaceStatistic')
        expect(results).to be_nil
      end
    end
  end

  describe 'analyzer_statuses' do
    let_it_be(:group) { create(:group) }
    let_it_be(:group_analyzer_statuses) { create(:analyzer_namespace_status, namespace: group) }
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
            group(fullPath: "#{group.full_path}") {
              analyzerStatuses {
                analyzerType
              }
            }
          }
        GQL
      end

      before do
        stub_licensed_features(security_inventory: licensed_feature)
        group.add_member(user, user_role)
      end

      subject(:search_results) do
        GitlabSchema.execute(query, context: { current_user: user }).as_json
      end

      it 'returns data only when expected' do
        results = search_results.dig('data', 'group', 'analyzerStatuses')
        expect(results.present?).to be(data_expected)
      end
    end
  end

  describe '#epics_enabled?' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:group) { create(:group) }

    let(:query) do
      <<~GQL
        query {
          group(fullPath: "#{group.full_path}") {
            id,
            epicsEnabled
          }
        }
      GQL
    end

    before_all do
      group.add_owner(current_user)
    end

    subject(:epics_enabled) do
      result = GitlabSchema.execute(query, context: { current_user: current_user }).as_json

      result.dig('data', 'group', 'epicsEnabled')
    end

    context 'when feature is available' do
      it 'returns true' do
        stub_licensed_features(epics: true)

        expect(epics_enabled).to be(true)
      end
    end

    context 'when feature is not available' do
      it 'returns false' do
        stub_licensed_features(epics: false)

        expect(epics_enabled).to be(false)
      end
    end
  end

  describe 'billable members count' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:group_owner) { create(:user) }
    let_it_be(:group_developer) { create(:user) }
    let_it_be(:group_guest) { create(:user) }
    let_it_be(:project_developer) { create(:user) }
    let_it_be(:project_guest) { create(:user) }

    let(:current_user) { group_owner }
    let(:query) do
      <<~GQL
        query {
          group(fullPath: "#{group.full_path}") {
            id,
            billableMembersCount
          }
        }
      GQL
    end

    before do
      group.add_owner(group_owner)
      group.add_developer(group_developer)
      group.add_guest(group_guest)
      project.add_developer(project_developer)
      project.add_guest(project_guest)
    end

    subject(:billable_members_count) do
      result = GitlabSchema.execute(query, context: { current_user: current_user }).as_json

      result.dig('data', 'group', 'billableMembersCount')
    end

    context 'when no plan is provided' do
      it 'returns billable users count including guests' do
        expect(billable_members_count).to eq(5)
      end
    end

    context 'when a plan is provided' do
      let(:query) do
        <<~GQL
          query {
            group(fullPath: "#{group.full_path}") {
              id,
              billableMembersCount(requestedHostedPlan: "#{plan}")
            }
          }
        GQL
      end

      context 'with a plan that should include guests is provided' do
        let(:plan) { ::Plan::SILVER }

        it 'returns billable users count including guests' do
          expect(billable_members_count).to eq(5)
        end
      end

      context 'with a plan that should exclude guests is provided' do
        let(:plan) { ::Plan::ULTIMATE }

        it 'returns billable users count excluding guests when a plan that should exclude guests is provided' do
          expect(billable_members_count).to eq(3)
        end
      end
    end

    context 'without owner authorization' do
      let(:current_user) { group_developer }

      it 'does not return the billable members count' do
        expect(billable_members_count).to be_nil
      end
    end
  end

  describe 'dora field' do
    subject { described_class.fields['dora'] }

    it { is_expected.to have_graphql_type(Types::Analytics::Dora::GroupDoraType) }
  end

  describe 'component_versions' do
    subject { described_class.fields['componentVersions'] }

    it { is_expected.to have_non_null_graphql_type(::Types::Sbom::ComponentVersionType.connection_type) }
    it { is_expected.to have_graphql_resolver(::Resolvers::Sbom::ComponentVersionResolver) }

    it { is_expected.to include_graphql_arguments(:component_name) }
  end

  describe 'virtual_registries_container_registries' do
    subject { described_class.fields['virtualRegistriesContainerRegistries'] }

    it 'has connection type class' do
      is_expected.to have_nullable_graphql_type(
        ::Types::VirtualRegistries::Container::RegistryType.connection_type
      )
    end
  end

  describe 'virtual_registries_packages_maven_registries' do
    subject { described_class.fields['virtualRegistriesPackagesMavenRegistries'] }

    it 'has connection type class' do
      is_expected.to have_nullable_graphql_type(
        ::Types::VirtualRegistries::Packages::Maven::RegistryType.connection_type
      )
    end
  end

  describe 'virtual_registries_packages_maven_upstreams' do
    subject { described_class.fields['virtualRegistriesPackagesMavenUpstreams'] }

    it 'has connection type class' do
      is_expected.to have_nullable_graphql_type(
        ::Types::VirtualRegistries::Packages::Maven::UpstreamType.connection_type
      )
    end

    it { is_expected.to have_graphql_resolver(::Resolvers::VirtualRegistries::Packages::Maven::UpstreamsResolver) }
  end

  describe 'virtual_registries_container_upstreams' do
    subject { described_class.fields['virtualRegistriesContainerUpstreams'] }

    it 'has connection type class' do
      is_expected.to have_nullable_graphql_type(
        ::Types::VirtualRegistries::Container::UpstreamType.connection_type
      )
    end

    it { is_expected.to have_graphql_resolver(::Resolvers::VirtualRegistries::Container::UpstreamsResolver) }
  end

  describe 'virtual_registries_cleanup_policy' do
    subject { described_class.fields['virtualRegistriesCleanupPolicy'] }

    it 'has connection type class' do
      is_expected.to have_nullable_graphql_type(
        ::Types::VirtualRegistries::Cleanup::PolicyType
      )
    end

    it { is_expected.to have_graphql_resolver(::Resolvers::VirtualRegistries::Cleanup::PolicyResolver) }
  end

  describe 'virtual registries setting' do
    before do
      stub_licensed_features(packages_virtual_registry: true)
    end

    let_it_be(:current_user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let(:query) do
      %(
        query {
          group(fullPath: "#{group.full_path}") {
            virtualRegistriesSetting {
              enabled
            }
          }
        }
      )
    end

    let(:query_result) { GitlabSchema.execute(query, context: { current_user: current_user }).as_json }

    subject(:virtual_registries_setting) { query_result.dig(*%w[data group virtualRegistriesSetting]) }

    context 'with authorization' do
      context 'when user is a maintainer' do
        before do
          group.add_maintainer(current_user)
        end

        it 'returns null' do
          expect(virtual_registries_setting).to be_nil
        end
      end

      context 'when user is an owner' do
        before do
          group.add_owner(current_user)
        end

        it 'returns the virtual registry setting' do
          expect(virtual_registries_setting['enabled']).to be(true)
        end
      end
    end

    context 'with the maven virtual registry feature flag turned off' do
      before do
        stub_feature_flags(maven_virtual_registry: false)
      end

      it 'returns null for the virtual registries setting' do
        expect(virtual_registries_setting).to be_nil
      end
    end

    context 'when package license is not available' do
      before do
        stub_licensed_features(packages_virtual_registry: false)
      end

      it 'returns null for the virtual registries setting' do
        expect(virtual_registries_setting).to be_nil
      end
    end

    context 'with a subgroup' do
      let_it_be(:parent_group) { group }
      let_it_be(:group) { create(:group, parent: parent_group) }
      let_it_be(:current_user) { create(:user, owner_of: [group, parent_group]) }

      it 'returns null for the virtual registries setting' do
        expect(virtual_registries_setting).to be_nil
      end
    end
  end
end
