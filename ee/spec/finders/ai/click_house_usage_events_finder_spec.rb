# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ClickHouseUsageEventsFinder, :click_house, feature_category: :value_stream_management do
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user, freeze: false) { create(:user, namespace: group) }
  let_it_be(:project_namespace, freeze: false) { project.project_namespace.reload }
  let_it_be(:user_contributor, freeze: false) { create(:user, namespace: project_namespace) }

  let_it_be(:to) { Time.zone.today }
  let_it_be(:from) { Time.zone.today - 20.days }

  let(:finder_params) do
    { from: from, to: to, namespace: group }
  end

  subject(:query_builder) { described_class.new(user, **finder_params).execute }

  describe '#execute' do
    before do
      clickhouse_fixture(:ai_usage_events, [
        { user_id: user.id, namespace_path: project_namespace.traversal_path(with_organization: false), event: 3,
          timestamp: to - 1.day },
        { user_id: user.id, namespace_path: group.traversal_path(with_organization: false), event: 2,
          timestamp: to - 1.day },
        { user_id: user_contributor.id, namespace_path: project_namespace.traversal_path(with_organization: false),
          event: 1, timestamp: from + 1.day },
        { user_id: user_contributor.id, namespace_path: project_namespace.traversal_path(with_organization: false),
          event: 3, timestamp: to + 1.day }, # out of range
        { user_id: user_contributor.id, namespace_path: project_namespace.traversal_path(with_organization: false),
          event: 4, timestamp: from - 1.day } # out of range
      ])
    end

    context 'when ClickHouse returns results' do
      it 'uses clickhouse query builder' do
        expect(query_builder).to be_an_instance_of(ClickHouse::Client::QueryBuilder)
        expect(query_builder.to_sql).to include('ai_usage_events')
        expect(query_builder.to_sql).to include('ORDER BY')
      end

      context 'when passing users' do
        let(:finder_params) do
          { from: from, to: to, namespace: group, users: [user_contributor.to_global_id.model_id] }
        end

        it 'filters by user' do
          expect(query_builder.to_sql).to include("`ai_usage_events`.`user_id` IN ('#{user_contributor.id}')")
        end
      end

      context 'when passing events' do
        let(:finder_params) do
          { from: from, to: to, namespace: group, events: [:code_suggestion_shown_in_ide] }
        end

        it 'filters by event' do
          expect(query_builder.to_sql).to include('`ai_usage_events`.`event` IN (2)')
          expect(query_builder.to_sql).not_to include('`ai_usage_events`.`event` IN (1)')
        end
      end

      context 'when passing time ranges' do
        it 'filters by date range' do
          expect(query_builder.to_sql)
          .to include("`ai_usage_events`.`timestamp` >= '#{from.to_time.utc.strftime('%Y-%m-%d %H:%M:%S')}'")
          expect(query_builder.to_sql)
          .to include("`ai_usage_events`.`timestamp` <= '#{to.to_time.utc.strftime('%Y-%m-%d %H:%M:%S')}'")
        end
      end
    end
  end
end
