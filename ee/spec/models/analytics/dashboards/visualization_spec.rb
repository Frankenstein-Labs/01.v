# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::Dashboards::Visualization, feature_category: :product_analytics do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) do
    create(:project, :with_product_analytics_dashboard, group: group,
      project_setting: build(:project_setting, product_analytics_instrumentation_key: 'test')
    )
  end

  let_it_be(:user) { create(:user) }

  let(:dashboards) { project.product_analytics_dashboards(user) }
  let(:num_custom_visualizations) { 2 }
  let(:project_vsd_available_visualizations) do
    %w[
      dora_chart
      usage_overview
      vsd_dora_metrics_table
      vsd_lifecycle_metrics_table
      vsd_security_metrics_table
      namespace_metadata
      issues_count
      merge_requests_count
      pipelines_count
    ]
  end

  let(:group_only_visualizations) do
    %w[dora_performers_score dora_projects_comparison groups_count users_count projects_count]
  end

  let(:group_vsd_available_visualizations) do
    [].concat(group_only_visualizations, project_vsd_available_visualizations)
  end

  let(:ai_impact_available_visualizations) do
    %w[
      ai_impact_table
      ai_impact_lifecycle_metrics_table
      ai_impact_ai_metrics_table
      duo_power_users_count_over_time
      duo_agent_chat_sessions_over_time
      pipeline_metrics_table
      code_suggestions_acceptance_by_language_chart
      duo_flow_metrics_table
      duo_flows_by_user
      code_generation_volume_trends_chart
      duo_code_review_usage_by_user
      duo_code_suggestions_by_user
      duo_rca_usage_by_user
      duo_total_event_count_by_user
      code_review_requests_by_role_chart
      code_suggestions_acceptance_by_ide_chart
      code_review_comments_sentiment_over_time_chart
      duo_users_count_over_time
      duo_agent_platform_agent_flows_users_count_over_time
      finished_pipelines_using_dap_over_time_chart
      duo_pipelines_rate_over_time
      duo_feature_user_retention_over_time
    ]
  end

  let(:dora_metrics_available_visualizations) do
    %w[
      change_failure_rate_over_time
      deployment_frequency_over_time
      lead_time_for_changes_over_time
      time_to_restore_service_over_time
      change_failure_rate
      deployment_frequency_average
      lead_time_for_changes_median
      time_to_restore_service_median
    ]
  end

  let(:mr_analytics_available_visualizations) do
    %w[
      mean_time_to_merge
      merge_requests_over_time
      merge_requests_throughput_table
    ]
  end

  before do
    allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(true)
    stub_licensed_features(
      product_analytics: true,
      project_level_analytics_dashboard: true,
      group_level_analytics_dashboard: true,
      project_merge_request_analytics: true
    )
    project.project_setting.update!(product_analytics_instrumentation_key: "key")
    allow_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |instance|
      allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: {
        'results' => [{ "data" => [{ "TrackedEvents.count" => "1" }] }]
      }))
    end

    allow(Ability).to receive(:allowed?)
                  .with(user, :read_dora4_analytics, anything)
                  .and_return(false)
    allow(Ability).to receive(:allowed?)
                  .with(user, :read_project_merge_request_analytics, anything)
                  .and_return(false)
  end

  shared_examples_for 'a valid visualization' do
    it 'returns a valid visualization' do
      expect(dashboard.panels.first.visualization).to be_a(described_class)
    end
  end

  shared_examples_for 'shows AI impact visualizations when available' do
    before do
      allow(Ability).to receive(:allowed?)
                    .with(user, :read_enterprise_ai_analytics, anything)
                    .and_return(true)
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
    end

    it 'includes built in visualizations for AI impact dashboard' do
      expect(visualizations.map(&:slug)).to include(*ai_impact_available_visualizations)
    end
  end

  shared_examples_for 'shows DORA Metrics visualizations when available' do
    before do
      allow(Ability).to receive(:allowed?)
                    .with(user, :read_enterprise_ai_analytics, anything)
                    .and_return(true)
                    .with(user, :read_dora4_analytics, anything)
                    .and_return(true)
    end

    it 'includes built in visualizations for DORA metrics dashboard' do
      expect(visualizations.map(&:slug)).to include(*dora_metrics_available_visualizations)
    end
  end

  shared_examples_for 'shows Merge request analytics visualizations when available' do
    before do
      allow(Ability).to receive(:allowed?)
                    .with(user, :read_project_merge_request_analytics, anything)
                    .and_return(true)
    end

    it 'includes built in visualizations for Merge request analytics dashboard' do
      expect(visualizations.map(&:slug)).to include(*mr_analytics_available_visualizations)
    end
  end

  describe '#slug' do
    subject(:visualizations) { described_class.for(container: project, user: user) }

    it 'returns the slugs' do
      expect(visualizations.map(&:slug)).to include('cube_bar_chart', 'cube_line_chart')
    end
  end

  describe '#schema_errors_for' do
    let(:dashboard) { dashboards.find { |d| d.title == 'Value Streams Dashboard' } }

    it 'fetches correct schema path' do
      allow(JSONSchemer).to receive(:schema).and_call_original
      expect(JSONSchemer).to receive(:schema).with(Rails.root.join(described_class::SCHEMA_PATH))

      dashboard.panels.first.visualization
    end
  end

  describe '.for' do
    context 'when resource_parent is a Project' do
      subject(:visualizations) { described_class.for(container: project, user: user) }

      it 'returns all visualizations stored in the project as well as built-in ones' do
        available_visualizations_count =
          num_custom_visualizations + project_vsd_available_visualizations.length

        expect(visualizations.count).to eq(available_visualizations_count)
        expect(visualizations.map { |v| v.config['type'] }).to include('BarChart', 'LineChart')
      end

      it 'returns the available project visualizations' do
        expect(visualizations.map(&:slug)).to include(*project_vsd_available_visualizations)

        expect(visualizations.map(&:slug)).not_to include(*group_only_visualizations)
      end

      context 'when a custom dashboard pointer project is configured' do
        let_it_be(:pointer_project) do
          create(:project, :with_product_analytics_custom_visualization, namespace: project.namespace)
        end

        before do
          project.update!(analytics_dashboards_configuration_project: pointer_project)
        end

        it 'returns custom visualizations from pointer project' do
          # :with_product_analytics_custom_visualization adds another visualization
          expected_visualizations_count = 1 + project_vsd_available_visualizations.length

          expect(visualizations.count).to eq(expected_visualizations_count)
          expect(visualizations.map(&:slug)).to include('example_custom_visualization')
        end

        it 'does not return custom visualizations from self' do
          expect(visualizations.map { |v| v.config['title'] }).not_to include('Daily Something', 'Example title')
        end
      end

      it_behaves_like 'shows AI impact visualizations when available'
      it_behaves_like 'shows Merge request analytics visualizations when available'
    end

    context 'when resource_parent is a group' do
      let_it_be_with_reload(:group) { create(:group) }

      subject(:visualizations) { described_class.for(container: group, user: user) }

      it 'returns built in visualizations' do
        expect(visualizations.map(&:slug)).to match_array(group_vsd_available_visualizations)
      end

      it 'returns the group only visualizations' do
        expect(visualizations.map(&:slug)).to include(*group_only_visualizations)
      end

      context 'when group value stream dashboard is not available' do
        before do
          stub_licensed_features(group_level_analytics_dashboard: false)
        end

        it 'does not include built in visualizations for VSD' do
          expect(visualizations.map(&:slug)).to be_empty
        end
      end

      context 'when a custom configuration project is defined' do
        let_it_be(:config_project) { create(:project, :with_product_analytics_custom_visualization, group: group) }

        before do
          group.update!(analytics_dashboards_configuration_project: config_project)
        end

        it 'returns builtin and custom visualizations' do
          expected_visualizations = [].concat(['example_custom_visualization'], group_vsd_available_visualizations)

          expect(visualizations.map(&:slug)).to match_array(expected_visualizations)
        end
      end

      it_behaves_like 'shows AI impact visualizations when available'
      it_behaves_like 'shows DORA Metrics visualizations when available'
    end
  end

  describe '.from_file' do
    where(:filename) do
      %w[
        usage_overview
        dora_chart
        vsd_lifecycle_metrics_table
        vsd_dora_metrics_table
        vsd_security_metrics_table
        dora_performers_score
        dora_projects_comparison
        deployment_frequency_over_time
        lead_time_for_changes_over_time
        time_to_restore_service_over_time
        change_failure_rate_over_time
        ai_impact_table
        ai_impact_lifecycle_metrics_table
        ai_impact_ai_metrics_table
        duo_feature_user_retention_over_time
        pushes
        merge_requests
        issues
        contributions_by_user
        namespace_metadata
      ]
    end

    with_them do
      it 'returns the correct visualization path' do
        visualization = described_class.from_file(filename: filename, config_project: project, container: project)

        expect(visualization.type).to be_present
        expect(visualization.slug).to eq(filename)
        expect(visualization.errors).to be_nil
      end
    end

    context 'when file cannot be opened' do
      it 'initializes visualization with errors' do
        visualization = described_class.from_file(filename: 'not-existing-file', config_project: project,
          container: project)

        expect(visualization.slug).to eq('not-existing-file')
        expect(visualization.errors).to match_array(['Visualization file not-existing-file.yaml not found'])
      end
    end
  end

  describe '.value_stream_dashboard_visualizations' do
    subject(:vsd_visualizations) { described_class.value_stream_dashboard_visualizations(project) }

    num_builtin_visualizations = 14

    it 'returns the value stream dashboard builtin visualizations' do
      expect(vsd_visualizations.count).to eq(num_builtin_visualizations)
    end
  end

  describe '.dora_metrics_visualizations' do
    subject(:dora_metrics_vis) { described_class.dora_metrics_visualizations(project) }

    num_builtin_visualizations = 8

    it 'returns the dora metrics dashboard builtin visualizations' do
      expect(dora_metrics_vis.count).to eq(num_builtin_visualizations)
    end
  end

  describe '.merge_requests_visualizations' do
    subject(:mr_visualizations) { described_class.merge_requests_visualizations(project) }

    it 'returns the merge request analytics dashboard builtin visualizations' do
      expect(mr_visualizations.count).to eq(3)
    end
  end

  context 'when dashboard is a built-in dashboard' do
    let(:dashboard) { dashboards.find { |d| d.title == 'Value Streams Dashboard' } }

    it_behaves_like 'a valid visualization'
  end

  context 'when dashboard is a local dashboard' do
    let(:dashboard) { dashboards.find { |d| d.title == 'Dashboard Example 1' } }

    it_behaves_like 'a valid visualization'
  end

  context 'when visualization is data not a file' do
    let_it_be_with_reload(:project) do
      create(:project, :with_product_analytics_dashboard_with_inline_visualization, group: group,
        project_setting: build(:project_setting, product_analytics_instrumentation_key: 'test')
      )
    end

    let(:dashboard) { dashboards.find { |d| d.title == 'Dashboard Example Inline Vis' } }

    it_behaves_like 'a valid visualization'
  end

  context 'when the inline visualization does not contain a slug' do
    let_it_be_with_reload(:project) do
      create(:project, :with_product_analytics_dashboard_with_inline_visualization_no_slug, group: group,
        project_setting: build(:project_setting, product_analytics_instrumentation_key: 'test')
      )
    end

    let(:dashboard) { dashboards.find { |d| d.title == 'Dashboard Example Inline Vis No Slug' } }

    it_behaves_like 'a valid visualization'

    it 'contains a randomly generated slug' do
      expect(dashboard.panels.first.visualization.slug).to be_a(String)
    end
  end

  context 'when visualization is loaded with attempted path traversal' do
    let_it_be_with_reload(:project) do
      create(:project, :with_dashboard_attempting_path_traversal, group: group,
        project_setting: build(:project_setting, product_analytics_instrumentation_key: 'test')
      )
    end

    let(:dashboard) { dashboards.find { |d| d.title == 'Dashboard Example 1' } }

    it 'raises an error' do
      expect { dashboard.panels.first.visualization }.to raise_error(Gitlab::PathTraversal::PathTraversalAttackError)
    end
  end

  context 'when visualization definition is invalid' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) do
      create(:project, :with_product_analytics_invalid_custom_visualization, group: group,
        project_setting: build(:project_setting, product_analytics_instrumentation_key: 'test')
      )
    end

    subject(:visualizations) { described_class.for(container: project, user: user) }

    it 'captures the error' do
      vis = (visualizations.select { |v| v.slug == 'example_invalid_custom_visualization' }).first
      expected = ["property '/type' is not one of: " \
        "[\"AreaChart\", \"LineChart\", \"ColumnChart\", \"DataTable\", \"Glql\", \"SingleStat\", " \
        "\"DORAChart\", \"UsageOverview\", \"DoraPerformersScore\", \"DoraProjectsComparison\", " \
        "\"AiImpactTable\", \"ContributionsByUserTable\", \"ContributionsPushesChart\", " \
        "\"ContributionsIssuesChart\", \"ContributionsMergeRequestsChart\", \"NamespaceMetadata\", " \
        "\"MergeRequestsThroughputTable\", \"BarChart\", \"StackedColumnChart\"]"]
      expect(vis&.errors).to match_array(expected)
    end
  end

  context 'when DataTable visualization includes invalid fields' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) do
      create(:project, :with_product_analytics_dashboard_with_invalid_datatable_fields, group: group,
        project_setting: build(:project_setting, product_analytics_instrumentation_key: 'test')
      )
    end

    let(:dashboard) { dashboards.find { |d| d.title == 'Invalid DataTable fields' } }

    it 'captures the error' do
      expect(dashboard.panels.first.visualization.errors).to match_array([
        "property '/options/fields/0/thAttr' is invalid: error_type=schema",
        "property '/options/fields/0/tdAttr' is invalid: error_type=schema",
        "property '/options/fields/1/key' does not match pattern: ^[a-zA-Z0-9][\\w-]*(\\.[a-zA-Z0-9][\\w-]*)*$"
      ])
    end
  end

  describe 'data query schema validation' do
    let(:schema) { Gitlab::Json::SafeParser.parse(File.read(Rails.root.join(described_class::SCHEMA_PATH))) }
    let(:all_query_types) { schema.dig('definitions', 'Data', 'properties', 'type', 'enum') }

    def build_config(type:, query:, visualization_type: 'DataTable')
      {
        'version' => 1,
        'type' => visualization_type,
        'options' => {},
        'data' => { 'type' => type, 'query' => query }
      }.to_yaml
    end

    def query_errors_for(type:, query:)
      described_class.new(container: project, config: build_config(type: type, query: query), slug: 'test').errors
    end

    it 'accepts every built-in visualization', :aggregate_failures do
      names = [
        *described_class::VALUE_STREAM_DASHBOARD_VISUALIZATIONS,
        *described_class::AI_IMPACT_DASHBOARD_VISUALIZATIONS,
        *described_class::DORA_METRICS_VISUALIZATIONS,
        *described_class::MERGE_REQUESTS_VISUALIZATIONS,
        *described_class::CONTRIBUTIONS_DASHBOARD_VISUALIZATIONS
      ]

      names.each do |name|
        visualization = described_class.from_file(filename: name, config_project: nil, container: project)

        expect(visualization.errors).to(
          be_nil, "expected built-in visualization '#{name}' to be valid, got: #{visualization.errors.inspect}"
        )
      end
    end

    it 'rejects unknown properties for every query type', :aggregate_failures do
      # cube_analytics forwards its query to the Cube API and has no fixed property allowlist.
      (all_query_types - %w[cube_analytics]).each do |type|
        errors = query_errors_for(type: type, query: { 'extraField' => 'x' })

        expect(errors).to(
          contain_exactly("property '/data/query/extraField' is invalid: error_type=schema"),
          "expected '#{type}' query to reject unknown properties, got: #{errors.inspect}"
        )
      end
    end
  end

  context 'when the visualization has syntax errors' do
    let_it_be(:invalid_yaml) do
      <<-YAML
---
invalid yaml here not good
other: okay1111
      YAML
    end

    subject(:visualization) { described_class.new(container: project, config: invalid_yaml, slug: 'test') }

    it 'captures the syntax error' do
      expect(visualization.errors).to match_array(['root is not of type: object'])
    end
  end

  context 'when initialized with init_error' do
    subject(:visualization) do
      described_class.new(container: project, config: nil, slug: "not-existing",
        init_error: "Some init error")
    end

    it 'captures the init_error' do
      expect(visualization.errors).to match_array(['Some init error'])
    end
  end

  describe 'handling slugs correctly' do
    subject(:visualization_slug) do
      described_class.new(container: project, config: nil, slug: slug,
        init_error: "Some init error").slug
    end

    context 'when slug contains a hyphen' do
      let(:slug) { 'hello-world' }

      it { is_expected.to eq 'hello-world' }
    end

    context 'when slug contains a underscore' do
      let(:slug) { 'hello_world' }

      it { is_expected.to eq 'hello_world' }
    end
  end
end
