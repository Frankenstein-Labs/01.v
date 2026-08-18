# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiAnalytics::TroubleshootUsageService, feature_category: :value_stream_management do
  subject(:service_response) do
    described_class.new(current_user, namespace: container, from: from, to: to).execute
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }
  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:user3) { create(:user) }
  let_it_be(:user4) { create(:user) }

  let(:current_user) { user1 }
  let(:from) { Time.current }
  let(:to) { Time.current }

  before do
    allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
  end

  shared_examples 'common ai usage rate service' do
    context 'when the clickhouse is not available for analytics' do
      before do
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).with(container).and_return(false)
      end

      it 'returns service error' do
        expect(service_response).to be_error

        message = s_('AiAnalytics|the ClickHouse data store is not available')
        expect(service_response.message).to eq(message)
      end
    end

    context 'when the feature is available', :click_house, :freeze_time do
      let(:from) { 14.days.ago }
      let(:to) { 1.day.ago }

      context 'without data' do
        it 'returns 0' do
          expect(service_response).to be_success
          expect(service_response.payload).to eq({
            root_cause_analysis_users_count: 0
          })
        end
      end

      context 'with only few fields selected' do
        it 'returns only selected fields' do
          response = described_class.new(current_user,
            namespace: container,
            from: from,
            to: to,
            fields: %i[root_cause_analysis_users_count foo]).execute

          expect(response.payload).to match(root_cause_analysis_users_count: 0)
        end
      end

      context 'with no selected fields' do
        it 'returns empty stats hash' do
          response = described_class.new(current_user,
            namespace: container,
            from: from,
            to: to,
            fields: []).execute

          expect(response).to be_success
          expect(response.payload).to eq({})
        end
      end

      context 'with data' do
        before do
          project_namespace = project.project_namespace.reload

          clickhouse_fixture(:ai_usage_events, [
            { user_id: user1.id, event: 7, namespace_path: group.traversal_path(with_organization: false),
              timestamp: to - 3.days },
            { user_id: user1.id, event: 7, namespace_path: project_namespace.traversal_path(with_organization: false),
              timestamp: to - 4.days },
            { user_id: user2.id, event: 7, namespace_path: project_namespace.traversal_path(with_organization: false),
              timestamp: to - 2.days },
            { user_id: user4.id, event: 7, namespace_path: subgroup.traversal_path(with_organization: false),
              timestamp: to - 2.days },
            # not matching
            { user_id: user3.id, event: 7, namespace_path: group.traversal_path(with_organization: false),
              timestamp: to + 2.days }, # too new
            { user_id: user3.id, event: 7, namespace_path: group.traversal_path(with_organization: false),
              timestamp: from - 2.days }, # too old
            { user_id: user3.id, event: 1, namespace_path: group.traversal_path(with_organization: false),
              timestamp: to - 2.days }
          ])
        end

        it 'returns matched troubleshoot AI usage stats' do
          expect(service_response).to be_success
          expect(service_response.payload).to match(
            root_cause_analysis_users_count: expected_events_count
          )
        end
      end
    end
  end

  context 'for group' do
    let_it_be(:container) { group }

    let(:expected_events_count) { 3 }

    it_behaves_like 'common ai usage rate service'
  end

  context 'for project' do
    let_it_be(:container) { project.project_namespace }

    let(:expected_events_count) { 2 }

    it_behaves_like 'common ai usage rate service'
  end
end
