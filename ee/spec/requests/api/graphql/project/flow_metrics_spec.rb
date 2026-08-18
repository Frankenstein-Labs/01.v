# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting project flow metrics', feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let(:full_path) { project1.full_path }
  let(:context) { :project }
  let_it_be(:project1) { create(:project, :repository, namespace: group) }
  # This is done so we can use the same count expectations in the shared examples and
  # reuse the shared example for the group-level test.
  let_it_be(:project2) { project1 }
  let_it_be(:production_environment1) { create(:environment, :production, project: project1) }
  let_it_be(:production_environment2) { production_environment1 }
  let_it_be(:current_user) { create(:user, maintainer_of: group) }

  before do
    # cycle_analytics_for_groups is needed for the aggregations
    stub_licensed_features(cycle_analytics_for_groups: true, cycle_analytics_for_projects: true)
  end

  it_behaves_like 'value stream analytics flow metrics deploymentCount examples' do
    let(:deployments) { [deployment1, deployment2, deployment3] }

    before do
      allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(false)

      deployments.each do |deployment|
        Dora::DailyMetrics.refresh!(deployment.environment, deployment.finished_at.to_date)
      end
    end

    it 'uses DORA data' do
      expect(Dora::DailyMetrics).to receive(:for_environments).and_call_original

      result
    end

    context 'when ClickHouse is enabled' do
      before do
        allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
        stub_feature_flags(dora_metrics_use_clickhouse: true)
      end

      it 'delegates to ClickhouseDeploymentCountService' do
        service = instance_double(::Analytics::CycleAnalytics::ClickHouse::DeploymentCountService, execute: 0)
        expect(::Analytics::CycleAnalytics::ClickHouse::DeploymentCountService).to receive(:new).and_return(service)

        result
      end

      context 'and dora_metrics_use_clickhouse feature flag is disabled' do
        before do
          stub_feature_flags(dora_metrics_use_clickhouse: false)
        end

        it 'uses DORA data' do
          expect(Dora::DailyMetrics).to receive(:for_environments).and_call_original

          result
        end
      end
    end
  end

  it_behaves_like 'value stream analytics flow metrics leadTime examples' do
    context 'when cycle analytics is not licensed' do
      before do
        stub_licensed_features(cycle_analytics_for_projects: false)
      end

      it 'returns nil' do
        expect(result).to be_nil
      end
    end
  end

  it_behaves_like 'value stream analytics flow metrics cycleTime examples' do
    context 'when cycle analytics is not licensed' do
      before do
        stub_licensed_features(cycle_analytics_for_projects: false)
      end

      it 'returns nil' do
        expect(result).to be_nil
      end
    end
  end

  it_behaves_like 'value stream analytics flow metrics issuesCompleted examples' do
    context 'when cycle analytics is not licensed' do
      before do
        stub_licensed_features(cycle_analytics_for_projects: false)
      end

      it 'returns nil' do
        expect(result).to be_nil
      end
    end
  end

  it_behaves_like 'value stream analytics flow metrics timeToMerge examples' do
    context 'when cycle analytics is not licensed' do
      before do
        stub_licensed_features(cycle_analytics_for_projects: false)
      end

      it 'returns nil' do
        expect(result).to be_nil
      end
    end
  end
end
