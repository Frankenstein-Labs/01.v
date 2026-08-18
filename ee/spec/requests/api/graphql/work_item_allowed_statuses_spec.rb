# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying work item allowed statuses', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group_1) { create(:group) }
  let_it_be(:group_2) { create(:group) }
  let_it_be(:project) { create(:project, group: group_2) }
  let_it_be(:user) { create(:user, guest_of: [group_1, project]) }

  let(:query) do
    <<~QUERY
    query {
      workItemAllowedStatuses {
        nodes {
          name
        }
      }
    }
    QUERY
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  RSpec.shared_examples 'does not return allowed statuses' do
    it 'returns an empty array' do
      post_graphql(query, current_user: user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:work_item_allowed_statuses, :nodes)).to eq([])
    end
  end

  context 'with only system-defined statuses' do
    it 'returns allowed statuses' do
      post_graphql(query, current_user: user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:work_item_allowed_statuses, :nodes)).to eq(
        [
          { "name" => "Done" },
          { "name" => "Duplicate" },
          { "name" => "In progress" },
          { "name" => "To do" },
          { "name" => "Won't do" }
        ]
      )
    end
  end

  context 'with system-defined and custom statuses' do
    let_it_be(:custom_status_1) { create(:work_item_custom_status, :to_do, name: 'To do', namespace: group_2) }
    let_it_be(:custom_status_2) { create(:work_item_custom_status, name: 'Ready for development', namespace: group_2) }

    it 'returns allowed statuses' do
      post_graphql(query, current_user: user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:work_item_allowed_statuses, :nodes)).to eq(
        [
          { "name" => "Done" },
          { "name" => "Duplicate" },
          { "name" => "In progress" },
          { "name" => "Ready for development" },
          { "name" => "To do" },
          { "name" => "Won't do" }
        ]
      )
    end
  end

  context 'when filtering by name' do
    context 'with exact match' do
      let(:query) do
        <<~QUERY
        query {
          workItemAllowedStatuses(name: "To do") {
            nodes {
              name
            }
          }
        }
        QUERY
      end

      context 'with only system-defined statuses' do
        it 'returns allowed statuses by name' do
          post_graphql(query, current_user: user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(graphql_data_at(:work_item_allowed_statuses, :nodes)).to eq([{ "name" => "To do" }])
        end
      end

      context 'with system-defined and custom statuses' do
        let_it_be(:custom_status_1) { create(:work_item_custom_status, :to_do, name: 'To do', namespace: group_2) }

        it 'returns allowed statuses by name' do
          post_graphql(query, current_user: user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(graphql_data_at(:work_item_allowed_statuses, :nodes)).to eq([{ "name" => "To do" }])
        end
      end
    end

    context 'with partial match' do
      let(:query) do
        <<~QUERY
        query {
          workItemAllowedStatuses(name: "do") {
            nodes {
              name
            }
          }
        }
        QUERY
      end

      context 'with only system-defined statuses' do
        it 'returns all allowed statuses containing the substring' do
          post_graphql(query, current_user: user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(graphql_data_at(:work_item_allowed_statuses, :nodes)).to match_array([
            { "name" => "To do" },
            { "name" => "Done" },
            { "name" => "Won't do" }
          ])
        end
      end

      context 'with system-defined and custom statuses' do
        let_it_be(:custom_status_1) { create(:work_item_custom_status, :to_do, name: 'To do', namespace: group_2) }

        it 'returns all allowed statuses containing the substring' do
          post_graphql(query, current_user: user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(graphql_data_at(:work_item_allowed_statuses, :nodes)).to match_array([
            { "name" => "To do" },
            { "name" => "Done" },
            { "name" => "Won't do" }
          ])
        end
      end
    end

    context 'when no statuses match the filter' do
      let(:query) do
        <<~QUERY
        query {
          workItemAllowedStatuses(name: "invalid") {
            nodes {
              name
            }
          }
        }
        QUERY
      end

      it_behaves_like 'does not return allowed statuses'
    end
  end

  context 'when user does not belong to any group' do
    it 'returns an empty array' do
      post_graphql(query, current_user: create(:user))

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:work_item_allowed_statuses, :nodes)).to eq([])
    end
  end

  context 'when work_item_status licensed feature is disabled' do
    before do
      stub_licensed_features(work_item_status: false)
    end

    it_behaves_like 'does not return allowed statuses'
  end
end
