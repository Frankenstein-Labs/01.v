# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.[project|group](fullPath).dora.metrics',
  time_travel_to: '2021-02-01 13:00:00'.to_time,
  feature_category: :dora_metrics do
  include GraphqlHelpers

  let_it_be(:reporter) { create(:user) }
  let(:query_body) do
    <<~QUERY
      dora {
        metrics {
          date
          deploymentFrequency
        }
      }
    QUERY
  end

  let_it_be(:group) { create(:group, reporters: [reporter]) }
  let_it_be(:project_1) { create(:project, group: group) }
  let_it_be(:project_2) { create(:project, group: group) }
  let_it_be(:project_not_in_group) { create(:project) }
  let_it_be(:production_in_project_1) { create(:environment, :production, project: project_1) }
  let_it_be(:staging_in_project_1) { create(:environment, :staging, project: project_1) }
  let_it_be(:production_in_project_2) { create(:environment, :production, project: project_2) }
  let_it_be(:production_not_in_group) { create(:environment, :production, project: project_not_in_group) }

  let(:number_of_days) { (Time.current.to_date - 3.months.ago.to_date).to_i + 1 }
  let(:post_query) { post_graphql(query, current_user: reporter) }
  let(:data) { graphql_data.dig(*path_prefix) }

  before_all do
    create(:dora_daily_metrics, deployment_frequency: 3, environment: production_in_project_1, date: '2021-01-01')
    create(:dora_daily_metrics, deployment_frequency: 3, environment: production_in_project_1, date: '2021-01-02')
    create(:dora_daily_metrics, deployment_frequency: 2, environment: production_in_project_1, date: '2021-01-03')
    create(:dora_daily_metrics, deployment_frequency: 2, environment: production_in_project_1, date: '2021-01-04')
    create(:dora_daily_metrics, deployment_frequency: 1, environment: production_in_project_1, date: '2021-01-05')
    create(:dora_daily_metrics, deployment_frequency: 1, environment: production_in_project_1, date: '2021-01-06')
    create(:dora_daily_metrics, incidents_count: 48, environment: production_in_project_1, date: '2021-01-07')

    create(:dora_daily_metrics, deployment_frequency: 4, environment: staging_in_project_1, date: '2021-01-08')

    create(:dora_daily_metrics, deployment_frequency: 4, environment: production_in_project_2, date: '2021-01-09')

    create(:dora_daily_metrics, deployment_frequency: 5, environment: production_not_in_group, date: '2021-01-10')
  end

  before do
    stub_licensed_features(dora4_analytics: true)
  end

  context 'when querying for project-level metrics' do
    let(:path_prefix) { %w[project dora metrics] }

    let(:query) do
      graphql_query_for(:project, { fullPath: project_1.full_path }, query_body)
    end

    it 'returns the expected project-level DORA metrics' do
      post_query

      expect(data).to eq(
        [
          *empty_metric_rows(from: '2020-11-01', to: '2020-12-31'),
          { 'deploymentFrequency' => 3, 'date' => '2021-01-01' },
          { 'deploymentFrequency' => 3, 'date' => '2021-01-02' },
          { 'deploymentFrequency' => 2, 'date' => '2021-01-03' },
          { 'deploymentFrequency' => 2, 'date' => '2021-01-04' },
          { 'deploymentFrequency' => 1, 'date' => '2021-01-05' },
          { 'deploymentFrequency' => 1, 'date' => '2021-01-06' },
          { 'deploymentFrequency' => nil, 'date' => '2021-01-07' },
          *empty_metric_rows(from: '2021-01-08', to: '2021-02-01')

        ]
      )
    end

    context 'when date field is not selected' do
      let(:query_body) do
        <<~QUERY
          dora {
            metrics {
              deploymentFrequency
            }
          }
        QUERY
      end

      it 'does not fill date range with nil values' do
        post_query

        expect(data).to eq(
          [
            { 'deploymentFrequency' => 3 },
            { 'deploymentFrequency' => 3 },
            { 'deploymentFrequency' => 2 },
            { 'deploymentFrequency' => 2 },
            { 'deploymentFrequency' => 1 },
            { 'deploymentFrequency' => 1 },
            { 'deploymentFrequency' => nil }
          ]
        )
      end
    end

    context 'when querying multiple metrics' do
      let(:query_body) do
        <<~QUERY
          dora {
            metrics(interval: ALL) {
              date
              deploymentFrequency
              changeFailureRate
            }
          }
        QUERY
      end

      it 'returns data for multiple metrics' do
        post_query

        df = 12
        expect(data).to match([
          { 'deploymentFrequency' => be_within(0.01).of(df.fdiv(number_of_days)), 'changeFailureRate' => 4,
            'date' => nil }
        ])
      end
    end
  end

  context 'when querying for group-level metrics' do
    let(:path_prefix) { %w[group dora metrics] }

    let(:query) do
      graphql_query_for(:group, { fullPath: group.full_path }, query_body)
    end

    it 'returns the expected group-level DORA metrics' do
      post_query

      expect(data).to eq(
        [
          *empty_metric_rows(from: '2020-11-01', to: '2020-12-31'),
          { 'deploymentFrequency' => 3, 'date' => '2021-01-01' },
          { 'deploymentFrequency' => 3, 'date' => '2021-01-02' },
          { 'deploymentFrequency' => 2, 'date' => '2021-01-03' },
          { 'deploymentFrequency' => 2, 'date' => '2021-01-04' },
          { 'deploymentFrequency' => 1, 'date' => '2021-01-05' },
          { 'deploymentFrequency' => 1, 'date' => '2021-01-06' },
          *empty_metric_rows(from: '2021-01-07', to: '2021-01-08'),
          { 'deploymentFrequency' => 4, 'date' => '2021-01-09' },
          *empty_metric_rows(from: '2021-01-10', to: '2021-02-01')
        ]
      )
    end

    context 'when date field is not selected' do
      let(:query_body) do
        <<~QUERY
          dora {
            metrics {
              deploymentFrequency
            }
          }
        QUERY
      end

      it 'does not fill date range with nil values' do
        post_query

        expect(data).to eq(
          [
            { 'deploymentFrequency' => 3 },
            { 'deploymentFrequency' => 3 },
            { 'deploymentFrequency' => 2 },
            { 'deploymentFrequency' => 2 },
            { 'deploymentFrequency' => 1 },
            { 'deploymentFrequency' => 1 },
            { 'deploymentFrequency' => nil },
            { 'deploymentFrequency' => 4 }
          ]
        )
      end
    end

    context 'when querying multiple metrics' do
      let(:query_body) do
        <<~QUERY
          dora {
            metrics(interval: ALL) {
              date
              deploymentFrequency
              changeFailureRate
            }
          }
        QUERY
      end

      it 'returns data for multiple metrics' do
        post_query

        df = 16
        expect(data).to match([
          { 'deploymentFrequency' => be_within(0.01).of(df.fdiv(number_of_days)), 'changeFailureRate' => 3,
            'date' => nil }
        ])
      end
    end
  end

  context 'when querying group dora projects' do
    let(:path_prefix) { %w[group dora projects nodes] }
    let(:query) do
      graphql_query_for(:group, { fullPath: group.full_path }, query_body)
    end

    let(:query_body) do
      <<~QUERY
        dora {
          projects(startDate: "2021-01-07", endDate: "2021-01-08", includeSubgroups: true) {
            nodes { id }
          }
        }
      QUERY
    end

    it 'returns list of projects with at least 1 DORA metric record' do
      post_query

      expect(data.pluck('id')).to match_array([project_1.to_global_id.to_s])
    end

    context 'with date range too large' do
      let(:query_body) do
        <<~QUERY
        dora {
          projects(startDate: "2020-01-09", endDate: "2021-02-01") {
            nodes { id }
          }
        }
        QUERY
      end

      it 'raises argument error' do
        post_query

        expect(graphql_errors[0]['message']).to eq("maximum date range is 180 days.")
      end
    end
  end

  def empty_metric_rows(from:, to:)
    empty_rows = []

    (from.to_date..to.to_date).step(1) do |date|
      row = { 'date' => date.to_s }
      row['deploymentFrequency'] = nil
      empty_rows << row
    end

    empty_rows
  end
end
