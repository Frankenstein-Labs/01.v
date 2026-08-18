# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project.aiCatalogItemConsumerForItem', feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:owning_project) { create(:project) }
  let_it_be(:consumer_project) { create(:project, :in_group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:item) { create(:ai_catalog_item, :public, project: owning_project) }

  let(:args) { { id: global_id_of(item) } }

  let(:query) do
    graphql_query_for(
      :project,
      { full_path: consumer_project.full_path },
      query_graphql_field(:ai_catalog_item_consumer_for_item,
        attributes_to_graphql(args).to_s,
        all_graphql_fields_for('AiCatalogItemConsumer', max_depth: 1)
      )
    )
  end

  let(:consumer_data) { graphql_data.dig('project', 'aiCatalogItemConsumerForItem') }

  before do
    enable_ai_catalog
  end

  context 'when the user can read item consumers on the project' do
    before_all do
      consumer_project.add_maintainer(user)
    end

    context 'when the item is enabled in the project' do
      let_it_be(:consumer) do
        create(:ai_catalog_item_consumer, item: item, project: consumer_project, enabled: true)
      end

      it 'returns the consumer with enabled=true' do
        post_graphql(query, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(consumer_data).to include(
          'id' => global_id_of(consumer).to_s,
          'enabled' => true
        )
      end
    end

    context 'when the item has a disabled consumer in the project' do
      let_it_be(:consumer) do
        create(:ai_catalog_item_consumer, item: item, project: consumer_project, enabled: false)
      end

      it 'returns the consumer with enabled=false' do
        post_graphql(query, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(consumer_data).to include(
          'id' => global_id_of(consumer).to_s,
          'enabled' => false
        )
      end
    end

    context 'when the item has no consumer in the project' do
      it 'returns null' do
        post_graphql(query, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(consumer_data).to be_nil
      end
    end

    context 'when the item has a consumer in a different project' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_consumer) do
        create(:ai_catalog_item_consumer, item: item, project: other_project, enabled: true)
      end

      before_all do
        other_project.add_maintainer(user)
      end

      it 'returns null for the queried project' do
        post_graphql(query, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(consumer_data).to be_nil
      end
    end

    it 'avoids N+1 database queries when loading consumers for multiple projects' do
      # We should create more consumers than the number we pass to `with_threshold`
      # to be confident that the extra queries are not due to an N+1
      consumer1 = create(:ai_catalog_item_consumer, item: item, project: consumer_project, enabled: true)
      consumer2 = create(:ai_catalog_item_consumer, item: item)
      consumer3 = create(:ai_catalog_item_consumer, item: item)

      consumer2.project.add_maintainer(user)
      consumer3.project.add_maintainer(user)

      query_without_consumers = <<~GQL
        query aiCatalogAvailableProjects {
          projects {
            nodes {
              id
              userPermissions {
                readAiCatalogItemConsumer
              }
            }
          }
        }
      GQL

      query_with_consumers = <<~GQL
        query aiCatalogAvailableProjects(
          $itemId: AiCatalogItemID!
        ) {
          projects {
            nodes {
              id
              userPermissions {
                readAiCatalogItemConsumer
              }
              aiCatalogItemConsumerForItem(id: $itemId) {
                id
              }
            }
          }
        }
      GQL

      post_graphql(query_without_consumers, current_user: user)

      control = ActiveRecord::QueryRecorder.new do
        post_graphql(query_without_consumers, current_user: user)
      end

      variables = { itemId: global_id_of(item).to_s }

      # Extra queries: consumers, items, ai_settings, and namespace_settings for root ancestors (policy checks)
      expect do
        post_graphql(query_with_consumers, variables: variables, current_user: user)
      end.not_to exceed_query_limit(control).with_threshold(4)

      returned_consumers = graphql_data.dig('projects', 'nodes').pluck('aiCatalogItemConsumerForItem')
      expect(returned_consumers).to include(
        a_graphql_entity_for(consumer1), a_graphql_entity_for(consumer2), a_graphql_entity_for(consumer3)
      )
    end
  end

  context 'when the user cannot read item consumers on the project' do
    let_it_be(:consumer) do
      create(:ai_catalog_item_consumer, item: item, project: consumer_project, enabled: true)
    end

    before_all do
      consumer_project.add_maintainer(user)
    end

    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?)
        .with(user, :read_ai_catalog_item_consumer, anything)
        .and_return(false)
    end

    it 'returns null' do
      post_graphql(query, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect(consumer_data).to be_nil
    end
  end
end
