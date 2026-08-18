# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Namespace.lifecycles', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:guest) { create(:user, guest_of: group) }

  let(:namespace) { group }
  let(:query) do
    <<~QUERY
    query {
      namespace(fullPath: "#{namespace.full_path}") {
        id
        lifecycles {
          nodes {
            id
            name
            defaultOpenStatus {
              id
            }
            defaultClosedStatus {
              id
            }
            defaultDuplicateStatus {
              id
            }
            workItemTypes {
              id
            }
          }
        }
      }
    }
    QUERY
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  shared_examples 'returns lifecycles' do
    it 'returns lifecycles for a given namespace' do
      post_graphql(query, current_user: guest)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:namespace, :lifecycles, :nodes)).to match_array(expected_lifecycles)
    end
  end

  context 'when user has permission to read lifecycles' do
    context 'with system-defined lifecycles' do
      let(:expected_lifecycles) do
        WorkItems::Statuses::SystemDefined::Lifecycle.all.map { |lifecycle| format_lifecycle(lifecycle) }
      end

      it_behaves_like 'returns lifecycles'

      context 'when namespace has custom work item types' do
        let!(:custom_work_item_type) do
          create(:work_item_custom_type, :with_organization, organization: group.organization)
        end

        it_behaves_like 'returns lifecycles'

        it 'returns custom work item types' do
          post_graphql(query, current_user: guest)

          expect(response).to have_gitlab_http_status(:ok)

          lifecycle_nodes = graphql_data_at(:namespace, :lifecycles, :nodes)
          work_item_type_ids = lifecycle_nodes.flat_map { |l| l['workItemTypes'].pluck('id') }

          expect(work_item_type_ids).to include(custom_work_item_type.to_global_id.to_s)
        end
      end
    end

    context 'with custom lifecycles' do
      let!(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: namespace.root_ancestor) }
      let(:expected_lifecycles) { [format_lifecycle(custom_lifecycle)] }

      it_behaves_like 'returns lifecycles'

      it 'avoids N+1 queries when fetching multiple lifecycles' do
        post_graphql(query, current_user: guest)

        control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: guest) }

        create_list(:work_item_custom_lifecycle, 2, namespace: namespace)

        expect { post_graphql(query, current_user: guest) }.not_to exceed_query_limit(control)
      end

      context 'when querying from a subgroup' do
        let_it_be(:subgroup) { create(:group, :private, parent: group) }
        let_it_be(:subgroup_guest) { create(:user, guest_of: subgroup) }

        let(:namespace) { subgroup }

        it 'returns custom lifecycles from the root ancestor' do
          post_graphql(query, current_user: subgroup_guest)

          expect(response).to have_gitlab_http_status(:ok)
          expect(graphql_data_at(:namespace, :lifecycles, :nodes)).to match_array(expected_lifecycles)
        end
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(work_item_status: false)
      end

      it 'does not return lifecycles' do
        post_graphql(query, current_user: guest)

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_data_at(:namespace, :lifecycles, :nodes)).to be_blank
      end
    end
  end

  context 'when user does not have permission to read lifecycles' do
    it 'does not return lifecycles' do
      post_graphql(query, current_user: create(:user))

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:namespace, :lifecycles, :nodes)).to be_blank
    end
  end

  context 'with an ai_workflows OAuth token' do
    let_it_be(:ai_workflows_oauth_token) do
      create(:oauth_access_token, user: guest, scopes: [:ai_workflows])
    end

    let!(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: namespace.root_ancestor) }
    let(:status) { custom_lifecycle.default_open_status }

    let(:query) do
      <<~QUERY
      query {
        namespace(fullPath: "#{namespace.full_path}") {
          id
          lifecycles {
            nodes {
              id
              name
              statuses {
                id
                name
              }
            }
          }
        }
      }
      QUERY
    end

    it 'resolves the full lifecycles -> statuses path for the ai_workflows scope' do
      post_graphql(query, token: { oauth_access_token: ai_workflows_oauth_token })

      expect(response).to have_gitlab_http_status(:ok)

      lifecycle_nodes = graphql_data_at(:namespace, :lifecycles, :nodes)

      expect(lifecycle_nodes).to include(
        a_hash_including(
          'id' => custom_lifecycle.to_global_id.to_s,
          'name' => custom_lifecycle.name,
          'statuses' => array_including(
            { 'id' => status.to_global_id.to_s, 'name' => status.name }
          )
        )
      )
    end
  end

  def format_lifecycle(lifecycle)
    {
      'id' => lifecycle.to_global_id.to_s,
      'name' => lifecycle.name,
      'defaultOpenStatus' => {
        'id' => lifecycle.default_open_status.to_global_id.to_s
      },
      'defaultClosedStatus' => {
        'id' => lifecycle.default_closed_status.to_global_id.to_s
      },
      'defaultDuplicateStatus' => {
        'id' => lifecycle.default_duplicate_status.to_global_id.to_s
      },
      'workItemTypes' => lifecycle.work_item_types(namespace).map do |type|
        {
          'id' => type.to_global_id.to_s
        }
      end
    }
  end
end
