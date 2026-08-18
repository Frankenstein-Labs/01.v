# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting the effective version of an AI catalog item', :with_current_organization, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:guest_user) { create(:user) }
  let_it_be(:group) { create(:group, guests: guest_user) }
  let_it_be(:project) do
    create(:project, group: group, guests: guest_user, organization: current_organization)
  end

  let_it_be_with_reload(:catalog_item) { create(:ai_catalog_item, :public, project: project) }

  let_it_be(:pinned_version) do
    create(:ai_catalog_agent_version, :released, version: '1.0.0', item: catalog_item)
  end

  let_it_be(:latest_version) do
    create(:ai_catalog_agent_version, :released, version: '2.0.0', item: catalog_item)
  end

  let(:current_user) { guest_user }
  let(:effective_version_data) { graphql_data_at(:ai_catalog_item, :effective_version) }
  let(:project_arg) { %(projectId: "#{project.to_global_id}") }
  let(:group_arg) { %(groupId: "#{group.to_global_id}") }
  let(:namespace_args) { project_arg }
  let(:effective_version_field) do
    namespace_args.empty? ? 'effectiveVersion' : "effectiveVersion(#{namespace_args})"
  end

  let(:query) do
    <<~GRAPHQL
      query {
        aiCatalogItem(id: "#{catalog_item.to_global_id}") {
          #{effective_version_field} {
            id
            versionName
          }
        }
      }
    GRAPHQL
  end

  before do
    catalog_item.update!(latest_version: latest_version, latest_released_version: latest_version)
    enable_ai_catalog
  end

  shared_examples 'resolves to' do |version_method|
    it "returns the #{version_method} version", :aggregate_failures do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(effective_version_data).to match(a_graphql_entity_for(send(version_method)))
    end
  end

  describe 'project namespace' do
    context 'when enabled for the project with a pinned version' do
      before do
        create(:ai_catalog_item_consumer, item: catalog_item, project: project, pinned_version_prefix: '1.0.0')
      end

      it_behaves_like 'resolves to', :pinned_version

      context 'when the current user cannot read the project consumer configuration' do
        let(:current_user) { create(:user) }

        it_behaves_like 'resolves to', :latest_version
      end

      context 'when also enabled for the group with a different pin' do
        before do
          create(:ai_catalog_item_consumer, item: catalog_item, group: group, pinned_version_prefix: '2.0.0')
        end

        it_behaves_like 'resolves to', :pinned_version
      end
    end

    context 'when enabled for the project without a pinned version' do
      before do
        create(:ai_catalog_item_consumer, item: catalog_item, project: project, pinned_version_prefix: nil)
      end

      it_behaves_like 'resolves to', :latest_version
    end

    context 'when not enabled for the project but enabled for the group with a pinned version' do
      before do
        create(:ai_catalog_item_consumer, item: catalog_item, group: group, pinned_version_prefix: '1.0.0')
      end

      it_behaves_like 'resolves to', :latest_version
    end

    context 'when not enabled for the project' do
      it_behaves_like 'resolves to', :latest_version
    end
  end

  describe 'group namespace' do
    let(:namespace_args) { group_arg }

    context 'when enabled for the group with a pinned version' do
      before do
        create(:ai_catalog_item_consumer, item: catalog_item, group: group, pinned_version_prefix: '1.0.0')
      end

      it_behaves_like 'resolves to', :pinned_version

      context 'when the current user cannot read the group consumer configuration' do
        let(:current_user) { create(:user) }

        it_behaves_like 'resolves to', :latest_version
      end
    end

    context 'when enabled for the group without a pinned version' do
      before do
        create(:ai_catalog_item_consumer, item: catalog_item, group: group, pinned_version_prefix: nil)
      end

      it_behaves_like 'resolves to', :latest_version
    end

    context 'when not enabled for the group' do
      it_behaves_like 'resolves to', :latest_version
    end
  end

  describe 'global namespace' do
    let(:namespace_args) { '' }

    it_behaves_like 'resolves to', :latest_version
  end

  it 'avoids N+1 queries when resolving pinned versions across a page', :request_store do
    pin_new_item = -> do
      item = create(:ai_catalog_item, :public, project: project)
      create(:ai_catalog_agent_version, :released, version: '1.0.0', item: item)
      create(:ai_catalog_item_consumer, item: item, project: project, pinned_version_prefix: '1.0.0')
    end

    version_query = 'SELECT "ai_catalog_item_versions"'
    list_query = <<~GRAPHQL
      query {
        aiCatalogItems {
          nodes {
            effectiveVersion(#{project_arg}) { id }
          }
        }
      }
    GRAPHQL

    create(:ai_catalog_item_consumer, item: catalog_item, project: project, pinned_version_prefix: '1.0.0')
    pin_new_item.call

    post_graphql(list_query, current_user: current_user) # warm up one-time setup queries

    control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
      post_graphql(list_query, current_user: current_user)
    end

    pin_new_item.call

    measurement = ActiveRecord::QueryRecorder.new(skip_cached: false) do
      post_graphql(list_query, current_user: current_user)
    end

    expect(measurement.occurrences_starting_with(version_query).values.sum)
      .to eq(control.occurrences_starting_with(version_query).values.sum)
  end

  describe 'when both projectId and groupId are given' do
    let(:namespace_args) { "#{project_arg}, #{group_arg}" }

    it 'returns a mutual exclusion error', :aggregate_failures do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to include(
        a_hash_including('message' => 'Only one of [projectId, groupId] arguments is allowed at the same time.')
      )
      expect(effective_version_data).to be_nil
    end
  end
end
