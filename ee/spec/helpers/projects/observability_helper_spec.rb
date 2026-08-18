# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe Projects::ObservabilityHelper, feature_category: :observability do
  include Gitlab::Routing.url_helpers

  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:project) { build_stubbed(:project, group: group) }

  let(:expected_api_config) do
    {
      analyticsUrl: ::Gitlab::Observability.analytics_url(project),
      tracingUrl: Gitlab::Observability.tracing_url(project),
      tracingAnalyticsUrl: Gitlab::Observability.tracing_analytics_url(project),
      servicesUrl: Gitlab::Observability.services_url(project),
      operationsUrl: Gitlab::Observability.operations_url(project),
      metricsUrl: Gitlab::Observability.metrics_url(project),
      metricsSearchUrl: Gitlab::Observability.metrics_search_url(project),
      metricsSearchMetadataUrl: Gitlab::Observability.metrics_search_metadata_url(project),
      logsSearchUrl: Gitlab::Observability.logs_search_url(project),
      logsSearchMetadataUrl: Gitlab::Observability.logs_search_metadata_url(project)
    }
  end

  describe '#observability_tracing_view_model' do
    it 'generates the correct JSON' do
      expected_json = {
        apiConfig: expected_api_config,
        projectFullPath: project.full_path,
        projectId: project.id
      }.to_json

      expect(helper.observability_tracing_view_model(project)).to eq(expected_json)
    end
  end

  describe '#observability_tracing_details_model' do
    it 'generates the correct JSON' do
      expected_json = {
        apiConfig: expected_api_config,
        projectFullPath: project.full_path,
        projectId: project.id,
        traceId: "trace-id",
        logsIndexUrl: namespace_project_logs_path(project.group, project),
        createIssueUrl: new_namespace_project_issue_path(project.group, project),
        metricsIndexUrl: namespace_project_metrics_path(project.group, project)
      }.to_json

      expect(helper.observability_tracing_details_model(project, "trace-id")).to eq(expected_json)
    end
  end

  describe '#observability_metrics_view_model' do
    it 'generates the correct JSON' do
      expected_json = {
        apiConfig: expected_api_config,
        projectFullPath: project.full_path,
        projectId: project.id
      }.to_json

      expect(helper.observability_metrics_view_model(project)).to eq(expected_json)
    end
  end

  describe '#observability_metrics_details_view_model' do
    it 'generates the correct JSON' do
      expected_json = {
        apiConfig: expected_api_config,
        projectFullPath: project.full_path,
        projectId: project.id,
        metricId: "test.metric",
        metricType: "metric_type",
        metricsIndexUrl: namespace_project_metrics_path(project.group, project),
        createIssueUrl: new_namespace_project_issue_path(project.group, project),
        tracingIndexUrl: namespace_project_tracing_index_path(project.group, project)
      }.to_json

      expect(helper.observability_metrics_details_view_model(project, "test.metric", "metric_type"))
        .to eq(expected_json)
    end
  end

  describe '#observability_logs_view_model' do
    it 'generates the correct JSON' do
      expected_json = {
        apiConfig: expected_api_config,
        projectFullPath: project.full_path,
        projectId: project.id,
        tracingIndexUrl: namespace_project_tracing_index_path(project.group, project),
        createIssueUrl: new_namespace_project_issue_path(project.group, project)
      }.to_json

      expect(helper.observability_logs_view_model(project)).to eq(expected_json)
    end
  end

  describe '#observability_usage_quota_view_model' do
    it 'generates the correct JSON' do
      expected_json = {
        apiConfig: expected_api_config,
        projectFullPath: project.full_path,
        projectId: project.id
      }.to_json

      expect(helper.observability_usage_quota_view_model(project)).to eq(expected_json)
    end
  end
end
