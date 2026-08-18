# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Recent items logging for group work items', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :public) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be(:epic_work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
  let_it_be(:epic) { epic_work_item.synced_epic }

  let(:query_work_item) { epic_work_item }
  let(:query) do
    graphql_query_for(
      'namespace',
      { 'fullPath' => group.full_path },
      query_graphql_field('workItem', { 'iid' => query_work_item.iid.to_s }, 'id iid title')
    )
  end

  before do
    stub_licensed_features(epics: true)
  end

  describe 'recent items logging' do
    context 'when work item is an epic' do
      it 'logs the epic model to recent items' do
        recent_epics_service = instance_double(::Gitlab::Search::RecentEpics)
        expect(::Gitlab::Search::RecentEpics).to receive(:new).with(user: user).and_return(recent_epics_service)
        expect(recent_epics_service).to receive(:log_view).with(epic)

        post_graphql(query, current_user: user)

        expect(graphql_errors).to be_blank
        expect(graphql_data_at(:namespace, :workItem)).to include('id' => epic_work_item.to_gid.to_s)
      end

      context 'when epic work item has no synced_epic (edge case)' do
        let_it_be(:epic_work_item_without_sync) { create(:work_item, :epic, namespace: group) }
        let(:query_work_item) { epic_work_item_without_sync }

        it 'logs the work item to recent items (fallback behavior)' do
          recent_epics_service = instance_double(::Gitlab::Search::RecentEpics)
          expect(::Gitlab::Search::RecentEpics).to receive(:new).with(user: user).and_return(recent_epics_service)
          expect(recent_epics_service).to receive(:log_view).with(epic_work_item_without_sync)

          post_graphql(query, current_user: user)

          expect(graphql_errors).to be_blank
          expect(graphql_data_at(:namespace, :workItem)).to include('id' => epic_work_item_without_sync.to_gid.to_s)
        end
      end
    end

    context 'when current_user is nil' do
      it 'does not log to recent items' do
        expect(::Gitlab::Search::RecentEpics).not_to receive(:new)

        post_graphql(query, current_user: nil)

        expect(graphql_errors).to be_blank
        # Work item is still returned for public groups, but recent items logging is skipped
        expect(graphql_data_at(:namespace, :workItem)).to include('id' => epic_work_item.to_gid.to_s)
      end
    end

    context 'when epics are not licensed' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'returns nil and does not log to recent items' do
        expect(::Gitlab::Search::RecentEpics).not_to receive(:new)

        post_graphql(query, current_user: user)

        expect(graphql_errors).to be_blank
        expect(graphql_data_at(:namespace, :workItem)).to be_nil
      end
    end

    context 'when work item does not exist' do
      let(:query) do
        graphql_query_for(
          'namespace',
          { 'fullPath' => group.full_path },
          query_graphql_field('workItem', { 'iid' => '999' }, 'id iid title')
        )
      end

      it 'does not log to recent items' do
        expect(::Gitlab::Search::RecentEpics).not_to receive(:new)

        post_graphql(query, current_user: user)

        expect(graphql_errors).to be_blank
        expect(graphql_data_at(:namespace, :workItem)).to be_nil
      end
    end
  end
end
