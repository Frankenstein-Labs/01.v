# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Projects::Analytics::ValueStreamDashboard::CountResolver, feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:developer) { create(:user, developer_of: group) }
  let_it_be(:other_user) { create(:user) }

  let_it_be(:project) { create(:project, namespace: group).reload }

  let_it_be(:count1) do
    create(:value_stream_dashboard_count, metric: :issues, count: 10, namespace: project.project_namespace,
      recorded_at: '2023-06-20')
  end

  let_it_be(:count2) do
    create(:value_stream_dashboard_count, metric: :issues, count: 30, namespace: project.project_namespace,
      recorded_at: '2023-05-20')
  end

  let_it_be(:count3) do
    create(:value_stream_dashboard_count, metric: :merge_requests, count: 20, namespace: project.project_namespace,
      recorded_at: '2023-05-20')
  end

  let(:arguments) { { identifier: 'issues', timeframe: { start: '2023-06-01', end: '2023-06-30' } } }
  let(:current_user) { developer }

  describe '#resolve' do
    subject(:result) { resolve(described_class, obj: project, args: arguments, ctx: { current_user: current_user }) }

    context 'when the feature is available' do
      before do
        stub_licensed_features(project_level_analytics_dashboard: true)
      end

      it 'returns the correct count' do
        expect(result[:count]).to eq(10)
      end

      context 'when requesting the contributors metric', :click_house do
        before do
          allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)

          arguments[:identifier] = 'contributors'

          clickhouse_fixture(:siphon_events, [
            # push event
            { id: 1, path: "#{group.organization_id}/#{group.id}/#{project.project_namespace.id}/", author_id: 100,
              target_id: 0, target_type: '', action: 5, created_at: '2023-06-10', updated_at: '2023-06-10' },
            # push event, different user
            { id: 2, path: "#{group.organization_id}/#{group.id}/#{project.project_namespace.id}/", author_id: 200,
              target_id: 0, target_type: '', action: 5, created_at: '2023-06-15', updated_at: '2023-06-15' }
          ])
        end

        it 'returns the correct count' do
          expect(result[:count]).to eq(2)
        end
      end

      context 'when querying an empty date range' do
        before do
          arguments[:timeframe][:start] = '2023-01-01'
          arguments[:timeframe][:end] = '2023-01-31'
        end

        it 'returns nil' do
          expect(result).to be_nil
        end
      end

      context 'when the user is not authorized' do
        let(:current_user) { other_user }

        it 'returns nil' do
          expect(result).to be_nil
        end
      end
    end

    context 'when the feature is not available' do
      it 'returns the correct count' do
        expect(result).to be_nil
      end
    end
  end
end
