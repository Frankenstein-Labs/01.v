# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Observability::AlertQueryWorker, feature_category: :observability do
  let_it_be(:active_token, freeze: true) { create(:service_access_token, :active) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:another_project) { create(:project, group: group) }

  let(:expected_instance_id) { Gitlab::GlobalAnonymousId.instance_id }
  let(:expected_gitlab_realm) { ::CloudConnector::GITLAB_REALM_SELF_MANAGED }

  let(:expected_access_token) { active_token.token }
  let(:expected_response) do
    [
      {
        "tenant_id" => "1",
        "project_id" => project.id.to_s,
        "agg_timestamp" => "2023-11-29T13:25:45Z",
        "alert_type" => "TraceRateLimitEvent",
        "description" => "rate limit exceeded on path: /v1/traces with method: POST",
        "reason" => "value of 1000 goes over the limit set to 100",
        "count" => "4"
      }
    ]
  end

  let(:expected_request_headers) do
    {
      'X-Gitlab-Instance-Id' => expected_instance_id,
      'X-Gitlab-Realm' => expected_gitlab_realm,
      'Authorization' => "Bearer #{expected_access_token}"
    }
  end

  let(:worker) { described_class.new }

  before do
    stub_request(:get, ::Gitlab::Observability.alerts_url)
      .with(
        headers: expected_request_headers
      )
      .to_return(
        status: 200,
        body: expected_response.to_json
      )

    allow(CloudConnector::Tokens).to receive(:get).and_return(expected_access_token)

    stub_licensed_features(observability: true, observability_alerts: true)
    stub_feature_flags(observability_features: true)
  end

  context 'when alerts are queried but none exists' do
    let(:expected_response) { [] }

    it 'calls alerts API' do
      expect(Gitlab::HTTP).to receive(:get).and_call_original

      worker.perform
    end
  end

  context 'when alerts are returned from API' do
    it 'creates alerts when receives payload' do
      expect { worker.perform }.to change { ::AlertManagement::Alert.count }.by(1)
    end

    it 'does not create duplicate alerts for the same event' do
      expect { worker.perform }.to change { ::AlertManagement::Alert.count }.by(1)
      expect { worker.perform }.not_to change { ::AlertManagement::Alert.count }
    end
  end

  context 'when alerts are returned for a non-existent project' do
    let(:expected_response) do
      [
        {
          "tenant_id" => "1",
          "project_id" => "1001",
          "agg_timestamp" => "2023-11-29T13:25:45Z",
          "alert_type" => "TraceRateLimitEvent",
          "description" => "rate limit exceeded on path: /v1/traces with method: POST",
          "reason" => "value of 1000 goes over the limit set to 100",
          "count" => 4
        }
      ]
    end

    it 'does not create any alerts',
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/18834' do
      expect { worker.perform }.not_to change { ::AlertManagement::Alert.count }
    end
  end

  context 'when alerts API returns malformed JSON' do
    it 'does not create any alerts' do
      stub_request(:get, ::Gitlab::Observability.alerts_url)
        .with(
          headers: expected_request_headers
        )
        .to_return(
          status: 200,
          body: "malformed-json"
        )
      expect { worker.perform }.not_to change { ::AlertManagement::Alert.count }
    end
  end

  context 'when alerts API is blocked' do
    it 'does not create any alerts' do
      stub_request(:get, ::Gitlab::Observability.alerts_url)
        .with(
          headers: expected_request_headers
        )
        .to_raise(Gitlab::HTTP_V2::BlockedUrlError)
      expect { worker.perform }.not_to change { ::AlertManagement::Alert.count }
    end
  end

  context 'when multiple alerts are returned from API' do
    let(:expected_response) do
      [
        {
          "tenant_id" => "1",
          "project_id" => project.id.to_s,
          "agg_timestamp" => "2023-11-29T13:25:45Z",
          "alert_type" => "TraceRateLimitEvent",
          "description" => "rate limit exceeded on path: /v1/traces with method: POST",
          "reason" => "value of 1000 goes over the limit set to 100",
          "count" => 4
        },
        {
          "tenant_id" => "22",
          "project_id" => another_project.id.to_s,
          "agg_timestamp" => "2024-08-13T10:48:00Z",
          "alert_type" => "MetricRateLimitEvent",
          "description" => "rate limit exceeded on path: /v1/metrics with method: POST",
          "reason" => "value of 445 goes over the limit set to 1",
          "count" => "5"
        },
        {
          "tenant_id" => "22",
          "project_id" => another_project.id.to_s,
          "agg_timestamp" => "2024-08-13T10:48:00Z",
          "alert_type" => "LogRateLimitEvent",
          "description" => "rate limit exceeded on path: /v1/logs with method: POST",
          "reason" => "value of 630 goes over the limit set to 1",
          "count" => "4"
        }
      ]
    end

    it 'creates alerts when receives payload' do
      expect { worker.perform }.to change { ::AlertManagement::Alert.count }.by(3)
    end
  end

  context 'when feature flags is disabled' do
    before do
      stub_feature_flags(observability_features: false)
    end

    it 'does not create any alert' do
      expect { worker.perform }.not_to change { ::AlertManagement::Alert.count }
    end
  end

  context 'when fetch_observability_alerts_from_cloud application setting is disabled' do
    before do
      stub_application_setting(fetch_observability_alerts_from_cloud: false)
    end

    it 'does not create any alert' do
      expect { worker.perform }.not_to change { ::AlertManagement::Alert.count }
    end
  end

  context 'when not licensed' do
    before do
      stub_licensed_features(observability_alerts: false, observability: false)
    end

    it 'does not create any alert' do
      expect { worker.perform }.not_to change { ::AlertManagement::Alert.count }
    end
  end

  context 'when disabled via project setting' do
    before do
      create(:project_setting, project: project, observability_alerts_enabled: false)
    end

    it 'does not create any alert' do
      expect { worker.perform }.not_to change { ::AlertManagement::Alert.count }
    end
  end
end
