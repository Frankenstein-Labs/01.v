# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Analytics::ValueStreamDashboard::CountResolver, feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:developer) { create(:user, developer_of: group) }
  let_it_be(:other_user) { create(:user) }

  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:count1) do
    create(:value_stream_dashboard_count, metric: :groups, count: 10, namespace: subgroup, recorded_at: '2023-05-20')
  end

  let_it_be(:count2) do
    create(:value_stream_dashboard_count, metric: :groups, count: 20, namespace: subgroup, recorded_at: '2023-04-20')
  end

  let(:arguments) { { identifier: 'groups', timeframe: { start: '2023-05-01', end: '2023-05-31' } } }
  let(:current_user) { developer }

  describe '#resolve' do
    subject(:result) { resolve(described_class, obj: group, args: arguments, ctx: { current_user: current_user }) }

    context 'when the feature is available' do
      before do
        stub_licensed_features(group_level_analytics_dashboard: true)
      end

      it 'returns the correct count' do
        expect(result[:count]).to eq(10)
      end

      context 'when requesting the contributors metric', :click_house do
        context 'when fetch_contributions_data_from_new_tables FF is enabled' do
          before do
            allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)

            arguments[:identifier] = 'contributors'

            clickhouse_fixture(:siphon_events, [
              # push event
              { id: 1, path: "#{group.organization_id}/#{group.id}/", author_id: 100, target_id: 0,
                target_type: '', action: 5, created_at: '2023-05-10', updated_at: '2023-05-10' },
              # push event, different user
              { id: 2, path: "#{group.organization_id}/#{group.id}/", author_id: 200, target_id: 0,
                target_type: '', action: 5, created_at: '2023-05-15', updated_at: '2023-05-15' },
              # otside of the date range
              { id: 3, path: "#{group.organization_id}/#{group.id}/", author_id: 300, target_id: 0,
                target_type: '', action: 5, created_at: '2023-06-15', updated_at: '2023-06-15' }
            ])
          end

          it 'returns the correct count' do
            expect(result[:count]).to eq(2)
          end
        end

        context 'when fetch_contributions_data_from_new_tables FF is disabled' do
          before do
            stub_feature_flags(fetch_contributions_data_from_new_tables: false)
            allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)

            arguments[:identifier] = 'contributors'

            clickhouse_fixture(:events, [
              # push event
              { id: 1, path: "#{group.id}/", author_id: 100, target_id: 0, target_type: '', action: 5,
                created_at: '2023-05-10', updated_at: '2023-05-10' },
              # push event, different user
              { id: 2, path: "#{group.id}/", author_id: 200, target_id: 0, target_type: '', action: 5,
                created_at: '2023-05-15', updated_at: '2023-05-15' },
              # otside of the date range
              { id: 3, path: "#{group.id}/", author_id: 300, target_id: 0, target_type: '', action: 5,
                created_at: '2023-06-15', updated_at: '2023-06-15' }
            ])
          end

          it 'returns the correct count' do
            expect(result[:count]).to eq(2)
          end
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
