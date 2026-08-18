# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiAnalytics::UsageEventCountService, feature_category: :value_stream_management do
  subject(:service_response) do
    described_class.new(
      current_user,
      namespace: container,
      from: from,
      to: to,
      fields: fields
    ).execute
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }
  let_it_be(:project_namespace) { project.reload.project_namespace }
  let_it_be(:user1) { create(:user, developer_of: group) }
  let_it_be(:user2) { create(:user, developer_of: group) }

  let(:current_user) { user1 }
  let(:from) { Time.current }
  let(:to) { Time.current }
  let(:fields) { [] }

  before do
    allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
  end

  shared_examples 'common ai usage rate service' do
    # This shared examples requires the following variables
    # :expected_results
    # :expected_language_filtered_results

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
      let(:from) { 5.days.ago }
      let(:to) { 1.day.ago }

      context 'without data' do
        it 'returns 0 for each event type' do
          empty_response =
            fields.each_with_object({}) do |event_name, result|
              result[event_name.to_sym] = 0
            end

          expect(service_response).to be_success
          expect(service_response.payload).to eq(empty_response)
        end
      end

      context 'with only few fields selected' do
        let(:fields) { %i[request_duo_chat_response foo] }

        it 'returns only valid fields' do
          expect(service_response.payload).to match(request_duo_chat_response: 0)
        end
      end

      context 'with no selected fields' do
        let(:fields) { [] }

        it 'returns empty stats hash' do
          expect(service_response).to be_success
          expect(service_response.payload).to eq({})
        end
      end

      context 'with data' do
        let(:fields) { %i[troubleshoot_job request_duo_chat_response] }

        before do
          clickhouse_fixture(:ai_usage_events, [
            # Troubleshoot job - event 7
            { user_id: user1.id, namespace_path: group.traversal_path(with_organization: false), event: 7,
              timestamp: to - 2.days },
            { user_id: user1.id, namespace_path: subgroup.traversal_path(with_organization: false), event: 7,
              timestamp: to - 2.days },
            { user_id: user2.id, namespace_path: project_namespace.traversal_path(with_organization: false), event: 7,
              timestamp: to - 3.days },
            { user_id: user2.id, namespace_path: project_namespace.traversal_path(with_organization: false), event: 7,
              timestamp: to - 2.days },
            # Request duo chat response - event 6
            { user_id: user1.id, namespace_path: group.traversal_path(with_organization: false), event: 6,
              timestamp: to - 2.days },
            { user_id: user2.id, namespace_path: project_namespace.traversal_path(with_organization: false), event: 6,
              timestamp: to - 2.days },
            { user_id: user2.id, namespace_path: project_namespace.traversal_path(with_organization: false), event: 6,
              timestamp: to - 2.days },
            # Request duo chat response - Outside of timeframe
            { user_id: user2.id, namespace_path: project_namespace.traversal_path(with_organization: false), event: 6,
              timestamp: to - 6.days }
          ])
        end

        it 'returns AI usage events counts' do
          expect(service_response).to be_success
          expect(service_response.payload).to match(expected_results)
        end

        context "when passing fields parameter with '_event_count' suffix" do
          let(:fields) { %i[troubleshoot_job_event_count request_duo_chat_response_event_count] }
          let(:expected_results) do
            super().transform_keys { |event| :"#{event}_event_count" }
          end

          it 'returns corresponding results' do
            expect(service_response).to be_success

            expect(service_response.payload).to match(expected_results)
          end
        end
      end
    end
  end

  context 'for group' do
    let_it_be(:container) { group }

    let(:expected_results) do
      {
        troubleshoot_job: 4,
        request_duo_chat_response: 3
      }
    end

    it_behaves_like 'common ai usage rate service'
  end

  context 'for project' do
    let_it_be(:container) { project.project_namespace.reload }

    let(:expected_results) do
      {
        troubleshoot_job: 2,
        request_duo_chat_response: 2
      }
    end

    it_behaves_like 'common ai usage rate service'
  end
end
