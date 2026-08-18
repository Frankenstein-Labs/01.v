# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::ValueStreamDashboard::ContributorCountService, :freeze_time, feature_category: :value_stream_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }
  let_it_be(:group) { create(:group, developers: user) }
  let_it_be(:from) { Date.new(2022, 5, 1) }
  let_it_be(:to) { Date.new(2022, 6, 10) }

  let(:current_user) { user }
  let(:namespace) { group }

  subject(:service_response) do
    described_class.new(
      namespace: namespace,
      current_user: current_user,
      from: from,
      to: to
    ).execute
  end

  before do
    allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
  end

  context 'when the clickhouse is not available for analytics' do
    before do
      allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(false)
    end

    it 'returns service error' do
      expect(service_response).to be_error

      message = s_('VsdContributorCount|the ClickHouse data store is not available for this namespace')
      expect(service_response.message).to eq(message)
    end
  end

  context 'when the user has no access to the group' do
    let(:current_user) { other_user }

    before do
      allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
      stub_licensed_features(group_level_analytics_dashboard: true)
    end

    it 'returns service error' do
      expect(service_response).to be_error

      message = s_('404|Not found')
      expect(service_response.message).to eq(message)
    end
  end

  context 'when the group is not licensed' do
    before do
      allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
      stub_licensed_features(group_level_analytics_dashboard: false)
    end

    it 'returns service error' do
      expect(service_response).to be_error

      message = s_('404|Not found')
      expect(service_response.message).to eq(message)
    end
  end

  context 'when a project namespace is given' do
    let_it_be(:project) { create(:project, group: group) }

    let!(:namespace) { project.reload.project_namespace }
    let!(:path) { "#{group.organization_id}/#{group.id}/#{namespace.id}/" }

    context 'when data present', :click_house do
      before do
        allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
        stub_licensed_features(project_level_analytics_dashboard: true)

        clickhouse_fixture(:siphon_events, [
          # push event
          { id: 1, path: path, author_id: 100, target_id: 0, target_type: '', action: 5,
            created_at: from + 5.days, updated_at: from + 5.days },
          # issue creation event, different user
          { id: 2, path: path, author_id: 200, target_id: 0, target_type: 'Issue', action: 1,
            created_at: from + 9.days, updated_at: from + 9.days }
        ])
      end

      it 'returns distinct contributor count from ClickHouse' do
        expect(service_response).to be_success
        expect(service_response.payload[:count]).to eq(2)
      end

      context 'when fetch_contributions_data_from_new_tables is disabled' do
        let(:path) { "#{group.id}/#{namespace.id}/" }

        before do
          stub_feature_flags(fetch_contributions_data_from_new_tables: false)

          clickhouse_fixture(:events, [
            # push event
            { id: 1, path: path, author_id: 100, target_id: 0, target_type: '', action: 5,
              created_at: from + 5.days, updated_at: from + 5.days },
            # issue creation event, different user
            { id: 2, path: path, author_id: 200, target_id: 0, target_type: 'Issue', action: 1,
              created_at: from + 9.days, updated_at: from + 9.days }
          ])
        end

        it 'returns distinct contributor count from ClickHouse' do
          expect(service_response).to be_success
          expect(service_response.payload[:count]).to eq(2)
        end
      end
    end

    context 'when the user is not authorized', :click_house do
      it 'returns service error' do
        allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)

        expect(service_response).to be_error

        message = s_('404|Not found')
        expect(service_response.message).to eq(message)
      end
    end
  end

  context 'when user namespace is given', :click_house do
    let(:namespace) { create(:namespace, owner: user) }

    it 'returns service error' do
      allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)

      expect(service_response).to be_error

      message = s_('404|Not found')
      expect(service_response.message).to eq(message)
    end
  end

  context 'when the feature is available', :click_house do
    let(:events_for_user1)  do
      [
        # push event
        { id: 1, path: path, author_id: 100, target_id: 0, target_type: '', action: 5,
          created_at: from + 5.days, updated_at: from + 5.days },
        # push event same user
        { id: 2, path: path, author_id: 100, target_id: 0, target_type: '', action: 5,
          created_at: from + 8.days, updated_at: from + 8.days }
      ]
    end

    before do
      allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
      stub_licensed_features(group_level_analytics_dashboard: true)
    end

    context 'when no data present' do
      it 'returns 0' do
        expect(service_response).to be_success
        expect(service_response[:count]).to eq(0)
      end
    end

    context 'when data present' do
      let(:path) { "#{group.organization_id}/#{group.id}/" }

      before do
        clickhouse_fixture(:siphon_events, [
          *events_for_user1,
          # issue creation event, different user
          { id: 3, path: path, author_id: 200, target_id: 0, target_type: 'Issue', action: 1,
            created_at: from + 9.days, updated_at: from + 9.days },
          # issue creation event, outside of the date range
          { id: 4, path: path, author_id: 200, target_id: 0, target_type: 'Issue', action: 1,
            created_at: from + 5.years, updated_at: from + 5.years },
          # issue creation event, for a different group
          { id: 5, path: "0/", author_id: 200, target_id: 0, target_type: 'Issue', action: 1, created_at: from + 2.days,
            updated_at: from + 2.days }
        ])
      end

      it 'returns distinct contributor count from ClickHouse' do
        expect(service_response).to be_success
        expect(service_response.payload[:count]).to eq(2)
      end

      context 'when event is marked as deleted' do
        it 'clears out user-related events' do
          # mark all events deleted
          clickhouse_fixture(:siphon_events, events_for_user1.map do |e|
            e.merge(_siphon_deleted: true, _siphon_replicated_at: Time.zone.now + 5.seconds)
          end)

          expect(service_response).to be_success
          expect(service_response.payload[:count]).to eq(1)
        end
      end
    end

    context 'when fetch_contributions_data_from_new_tables is disabled' do
      let(:path) { "#{group.id}/" }

      before do
        stub_feature_flags(fetch_contributions_data_from_new_tables: false)

        clickhouse_fixture(:events, [
          *events_for_user1,
          # issue creation event, different user
          { id: 3, path: path, author_id: 200, target_id: 0, target_type: 'Issue', action: 1,
            created_at: from + 9.days, updated_at: from + 9.days },
          # issue creation event, outside of the date range
          { id: 4, path: path, author_id: 200, target_id: 0, target_type: 'Issue', action: 1,
            created_at: from + 5.years, updated_at: from + 5.years },
          # issue creation event, for a different group
          { id: 5, path: "0/", author_id: 200, target_id: 0, target_type: 'Issue', action: 1, created_at: from + 2.days,
            updated_at: from + 2.days }
        ])
      end

      it 'returns distinct contributor count from ClickHouse' do
        expect(service_response).to be_success
        expect(service_response.payload[:count]).to eq(2)
      end

      context 'when event is marked as deleted' do
        it 'does not clear out user-related events' do
          # mark all events deleted
          clickhouse_fixture(:siphon_events, events_for_user1.map { |e| e.merge!(_siphon_deleted: true) })

          expect(service_response).to be_success
          expect(service_response.payload[:count]).to eq(2)
        end
      end
    end
  end
end
