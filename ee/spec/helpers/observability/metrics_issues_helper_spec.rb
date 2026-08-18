# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Observability::MetricsIssuesHelper, feature_category: :observability do
  describe '#observability_metrics_issues_params' do
    let(:params) do
      {
        'name' => 'CPU Usage High',
        'fullUrl' => 'http://example.com/metric/123',
        'type' => 'gauge',
        'timeframe' => ['2024-08-14T00:00:00Z', '2024-08-14T23:59:59Z']
      }
    end

    context 'when params are blank' do
      it 'returns an empty hash' do
        expect(helper.observability_metrics_issues_params({})).to eq({})
        expect(helper.observability_metrics_issues_params(nil)).to eq({})
      end
    end

    context 'when params are present' do
      it 'returns the correct hash' do
        result = helper.observability_metrics_issues_params(params)

        expect(result).to be_a(Hash)
        expect(result[:title]).to eq("Issue created from CPU Usage High")
        expect(result[:description]).to eq(
          <<~TEXT
            [Metric details](http://example.com/metric/123) \\
            Name: `CPU Usage High` \\
            Type: `gauge` \\
            Timeframe: `2024-08-14T00:00:00Z - 2024-08-14T23:59:59Z`
          TEXT
        )
      end

      it 'adds the image to the text description if imageSnapshotUrl is present' do
        params['imageSnapshotUrl'] = 'http://example.com/image.png'
        result = helper.observability_metrics_issues_params(params)
        expect(result[:description]).to eq(
          <<~TEXT
            [Metric details](http://example.com/metric/123) \\
            Name: `CPU Usage High` \\
            Type: `gauge` \\
            Timeframe: `2024-08-14T00:00:00Z - 2024-08-14T23:59:59Z`
            | Snapshot |
            | ------ |
            | ![metric_snapshot](http://example.com/image.png) |
          TEXT
        )
      end
    end
  end
end
