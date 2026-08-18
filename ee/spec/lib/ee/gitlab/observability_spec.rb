# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Observability, feature_category: :observability do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  describe '.tracing_url' do
    subject { described_class.tracing_url(project) }

    it { is_expected.to eq("/api/v4/projects/#{project.id}/observability/v1/traces") }
  end

  describe '.tracing_analytics_url' do
    subject { described_class.tracing_analytics_url(project) }

    it { is_expected.to eq("/api/v4/projects/#{project.id}/observability/v1/traces/analytics") }
  end

  describe '.services_url' do
    subject { described_class.services_url(project) }

    it { is_expected.to eq("/api/v4/projects/#{project.id}/observability/v1/services") }
  end

  describe '.operations_url' do
    subject { described_class.operations_url(project) }

    it do
      is_expected.to eq(
        "/api/v4/projects/#{project.id}/observability/v1/services/$SERVICE_NAME$/operations"
      )
    end
  end

  describe '.metrics_url' do
    subject { described_class.metrics_url(project) }

    it { is_expected.to eq("/api/v4/projects/#{project.id}/observability/v1/metrics/autocomplete") }
  end

  describe '.metrics_search_url' do
    subject { described_class.metrics_search_url(project) }

    it { is_expected.to eq("/api/v4/projects/#{project.id}/observability/v1/metrics/search") }
  end

  describe '.metrics_search_metadata_url' do
    subject { described_class.metrics_search_metadata_url(project) }

    it { is_expected.to eq("/api/v4/projects/#{project.id}/observability/v1/metrics/searchmetadata") }
  end

  describe '.logs_search_url' do
    subject { described_class.logs_search_url(project) }

    it { is_expected.to eq("/api/v4/projects/#{project.id}/observability/v1/logs/search") }
  end

  describe '.logs_search_metadata_url' do
    subject { described_class.logs_search_metadata_url(project) }

    it { is_expected.to eq("/api/v4/projects/#{project.id}/observability/v1/logs/searchmetadata") }
  end

  describe '.analytics_url' do
    subject { described_class.analytics_url(project) }

    it { is_expected.to eq("/api/v4/projects/#{project.id}/observability/v1/analytics/storage") }
  end
end
