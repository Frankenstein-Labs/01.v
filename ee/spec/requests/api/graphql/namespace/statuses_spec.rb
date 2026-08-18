# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Namespace.statuses', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:guest) { create(:user, guest_of: group) }

  let(:namespace) { group }
  let(:query) do
    <<~QUERY
    query {
      namespace(fullPath: "#{namespace.full_path}") {
        id
        statuses {
          nodes {
            id
            name
            iconName
            color
            description
            category
          }
        }
      }
    }
    QUERY
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  shared_examples 'returns statuses' do
    it 'returns statuses for a given namespace' do
      post_graphql(query, current_user: guest)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:namespace, :statuses, :nodes)).to match_array(expected_statuses)
    end
  end

  shared_examples 'does not return statuses' do
    it 'does not return statuses' do
      post_graphql(query, current_user: guest)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:namespace, :statuses, :nodes)).to be_blank
    end
  end

  context 'when user has permission to read statuses' do
    context 'with system-defined statuses' do
      let(:expected_statuses) do
        WorkItems::Statuses::SystemDefined::Status.all.map { |status| format_status(status) }
      end

      it_behaves_like 'returns statuses'
    end

    context 'with custom statuses' do
      let!(:expected_statuses) do
        create_list(:work_item_custom_status, 2, namespace: namespace).map { |status| format_status(status) }
      end

      it_behaves_like 'returns statuses'

      it 'avoids N+1 queries when fetching multiple statuses' do
        post_graphql(query, current_user: guest)

        control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: guest) }

        create_list(:work_item_custom_status, 2, namespace: namespace)

        expect { post_graphql(query, current_user: guest) }.not_to exceed_query_limit(control)
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(work_item_status: false)
      end

      it_behaves_like 'does not return statuses'
    end
  end

  context 'when user does not have permission to read statuses' do
    let_it_be(:guest) { nil }

    it_behaves_like 'does not return statuses'
  end

  context 'when filtering by ids' do
    let(:query) do
      <<~QUERY
      query($ids: [WorkItemsStatusesStatusID!]) {
        namespace(fullPath: "#{namespace.full_path}") {
          id
          statuses(ids: $ids) {
            nodes {
              id
              name
            }
          }
        }
      }
      QUERY
    end

    shared_examples 'filters by the given ids' do
      it 'returns only the statuses matching the given ids' do
        post_graphql(query, current_user: guest, variables: { ids: [selected_status.to_global_id.to_s] })

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_data_at(:namespace, :statuses, :nodes)).to contain_exactly(
          a_hash_including('id' => selected_status.to_global_id.to_s)
        )
      end

      it 'returns no statuses when the id list is empty' do
        post_graphql(query, current_user: guest, variables: { ids: [] })

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_data_at(:namespace, :statuses, :nodes)).to be_empty
      end

      it 'returns every status when ids is null' do
        post_graphql(query, current_user: guest, variables: { ids: nil })

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_errors).to be_nil
        expect(graphql_data_at(:namespace, :statuses, :nodes).size).to eq(all_statuses_count)
      end
    end

    context 'with system-defined statuses' do
      let(:selected_status) { WorkItems::Statuses::SystemDefined::Status.all.first }
      let(:all_statuses_count) { WorkItems::Statuses::SystemDefined::Status.all.size }

      it_behaves_like 'filters by the given ids'
    end

    context 'with custom statuses' do
      let!(:other_status) { create(:work_item_custom_status, namespace: namespace) }
      let!(:selected_status) { create(:work_item_custom_status, namespace: namespace) }
      let(:all_statuses_count) { 2 }

      it_behaves_like 'filters by the given ids'
    end

    context 'when an id belongs to another model' do
      let_it_be(:other_user) { create(:user) }

      it 'rejects the id instead of matching a status with the same numeric id' do
        post_graphql(query, current_user: guest, variables: { ids: [other_user.to_global_id.to_s] })

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_errors.first['message'])
          .to include('does not represent an instance of WorkItems::Statuses::Status')
      end
    end

    context 'when more ids than the maximum are given' do
      let(:too_many_ids) do
        max = Resolvers::WorkItems::StatusesResolver::MAX_IDS

        Array.new(max + 1) { |index| "gid://gitlab/WorkItems::Statuses::SystemDefined::Status/#{index + 1}" }
      end

      it 'rejects the query' do
        post_graphql(query, current_user: guest, variables: { ids: too_many_ids })

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_errors.first['message']).to include('is too long')
      end
    end

    context 'when a requested id no longer exists' do
      # The namespace needs a custom status left over after `selected_status` is
      # destroyed below, otherwise it falls back to the system-defined statuses
      # and we would not be testing a missing custom status any more.
      let!(:other_status) { create(:work_item_custom_status, namespace: namespace) }
      let!(:selected_status) { create(:work_item_custom_status, namespace: namespace) }

      it 'returns only the ids that still exist' do
        deleted_status_gid = selected_status.to_global_id.to_s
        selected_status.destroy!

        post_graphql(query, current_user: guest, variables: { ids: [deleted_status_gid] })

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_data_at(:namespace, :statuses, :nodes)).to be_blank
      end
    end
  end

  def format_status(status)
    {
      'id' => status.to_global_id.to_s,
      'name' => status.name,
      'iconName' => status.icon_name,
      'color' => status.color,
      'description' => status.description,
      'category' => status.category.to_s
    }
  end
end
