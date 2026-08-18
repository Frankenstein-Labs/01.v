# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Observability::OpenTelemetryMetricTypeEnum, feature_category: :observability do
  let(:expected_values) do
    ::Observability::MetricsIssuesConnection.metric_types.keys.map(&:upcase)
  end

  subject { described_class.values.keys }

  it { is_expected.to contain_exactly(*expected_values) }
end
