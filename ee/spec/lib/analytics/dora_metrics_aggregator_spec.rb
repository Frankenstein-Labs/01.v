# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::DoraMetricsAggregator, feature_category: :devops_reports do
  describe '.aggregate_for', :freeze_time do
    let_it_be(:project) { create(:project) }
    let(:metric) { 'deployment_frequency' }
    let(:end_date) { Date.parse('2022-03-03') }
    let(:start_date) { Date.parse('2022-01-20') }
    let(:params) do
      {
        projects: [project],
        start_date: start_date,
        end_date: end_date,
        metrics: [metric],
        environment_tiers: ['production'],
        interval: Dora::DailyMetrics::INTERVAL_DAILY
      }.merge(extra_params)
    end

    let(:extra_params) { {} }
    let_it_be(:production) { create(:environment, :production, project: project) }
    let_it_be(:staging) { create(:environment, :staging, project: project) }

    let(:days_in_january) { 12 }
    let(:days_in_february) { 28 }
    let(:days_in_march) { 3 }
    let(:total_days) { days_in_january + days_in_february + days_in_march }

    subject { described_class.aggregate_for(**params) }

    before_all do
      create(:dora_daily_metrics, deployment_frequency: 2, environment: production, date: Date.parse('2022-01-25'))
      create(:dora_daily_metrics, deployment_frequency: 5, environment: production, date: Date.parse('2022-01-28'))
      create(:dora_daily_metrics, deployment_frequency: 9, environment: production, date: Date.parse('2022-02-07'))
      create(:dora_daily_metrics, deployment_frequency: 1, environment: production, date: Date.parse('2022-03-01'))
      create(:dora_daily_metrics, deployment_frequency: 1, environment: staging, date: Date.parse('2022-01-26'))
    end

    before do
      stub_licensed_features(dora4_analytics: true)
    end

    it 'returns the aggregated data' do
      expect(subject).to match_array([
        { 'date' => Date.parse('2022-01-25'), metric => 2 },
        { 'date' => Date.parse('2022-01-28'), metric => 5 },
        { 'date' => Date.parse('2022-02-07'), metric => 9 },
        { 'date' => Date.parse('2022-03-01'), metric => 1 }
      ])
    end

    context 'when interval is monthly' do
      let(:extra_params) { { interval: Dora::DailyMetrics::INTERVAL_MONTHLY } }

      it 'returns the aggregated data' do
        expect(subject).to match_array([
          { 'date' => Date.parse('2022-01-01'), 'deployment_count' => 7,
            metric => 7.fdiv(days_in_january) },
          { 'date' => Date.parse('2022-02-01'), 'deployment_count' => 9,
            metric => 9.fdiv(days_in_february) },
          { 'date' => Date.parse('2022-03-01'), 'deployment_count' => 1,
            metric => 1.fdiv(days_in_march) }
        ])
      end
    end

    context 'when interval is all' do
      let(:extra_params) { { interval: Dora::DailyMetrics::INTERVAL_ALL } }

      it 'returns the aggregated data' do
        expect(subject).to match_array([{ 'date' => nil, 'deployment_count' => 17, metric => 17.fdiv(total_days) }])
      end
    end

    context 'when environment tiers are changed' do
      let(:extra_params) { { environment_tiers: ['staging'] } }

      it 'returns the aggregated data' do
        expect(subject).to match_array([{ 'date' => Date.parse('2022-01-26'), metric => 1 }])
      end
    end
  end
end
