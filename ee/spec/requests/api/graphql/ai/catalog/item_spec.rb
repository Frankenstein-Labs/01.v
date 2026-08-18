# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting an AI catalog item', :with_current_organization, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:guest_user, freeze: false) { create(:user) }
  let_it_be(:developer_user, freeze: false) { create(:user) }

  let_it_be(:project, freeze: false) do
    create(:project, :in_group, guests: guest_user, developers: developer_user, organization: current_organization)
  end

  let_it_be_with_reload(:catalog_item) { create(:ai_catalog_item, :public, project: project) }
  let_it_be(:mcp_server, freeze: false) { create(:ai_catalog_mcp_server, organization: current_organization) }

  let!(:latest_version) do
    version = catalog_item.latest_version
    version.dws_flow_config_validated = true
    version.update!(definition: version.definition.merge(mcp_servers: [mcp_server.id]))
    version
  end

  let(:data) { graphql_data_at(:ai_catalog_item) }
  let(:params) { { id: catalog_item.to_global_id } }
  let(:query_args) { attributes_to_graphql(params) }
  let(:current_user) { nil }

  let(:query) do
    <<~GRAPHQL
      fragment VersionFragment on AiCatalogItemVersion {
        id
        updatedAt
        createdAt
        releasedAt
        released
        humanVersionName
        versionName
        ... on AiCatalogFlowVersion {
          definition
        }
        ... on AiCatalogAgentVersion {
          systemPrompt
          tools {
            nodes {
              id
            }
          }
          mcpServers {
            nodes {
              id
            }
          }
          userPrompt
        }
      }

      query {
        aiCatalogItem(#{query_args}) {
          description
          id
          itemType
          name
          public
          project { id }
          softDeleted
          softDeletedAt
          verificationLevel
          latestVersion {
            ...VersionFragment
          }
          versions {
            count
            nodes {
              ...VersionFragment
            }
          }
        }
      }
    GRAPHQL
  end

  before do
    enable_ai_catalog
  end

  shared_examples 'a successful query' do
    it 'returns the AI catalog item with its versions' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(data).to match(
        hash_including(
          'id' => catalog_item.to_global_id.to_s,
          'name' => catalog_item.name,
          'description' => catalog_item.description,
          'itemType' => 'AGENT',
          'public' => catalog_item.visibility_public?,
          'softDeleted' => catalog_item.deleted?,
          'softDeletedAt' => catalog_item.deleted_at&.iso8601,
          'verificationLevel' => catalog_item.verification_level.upcase,
          'latestVersion' => a_graphql_entity_for(latest_version),
          'versions' => hash_including(
            'count' => 1,
            'nodes' => contain_exactly(
              hash_including(
                'id' => latest_version.to_global_id.to_s,
                'systemPrompt' => latest_version.definition['system_prompt'],
                'userPrompt' => latest_version.definition['user_prompt'],
                'tools' => {
                  'nodes' => match_array(
                    latest_version.definition['tools'].map do |id|
                      a_graphql_entity_for(Ai::Catalog::BuiltInTool.find(id))
                    end
                  )
                },
                'mcpServers' => {
                  'nodes' => []
                },
                'updatedAt' => latest_version.updated_at.iso8601,
                'releasedAt' => latest_version.release_date&.iso8601,
                'released' => latest_version.released?,
                'versionName' => latest_version.version,
                'humanVersionName' => latest_version.human_version,
                'createdAt' => latest_version.created_at.iso8601
              )
            )
          )
        )
      )
    end
  end

  shared_examples 'an unsuccessful query' do
    it 'returns nil' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(data).to be_nil
    end
  end

  context 'with a public catalog item' do
    it_behaves_like 'a successful query'

    context 'when the item does not exist' do
      let(:params) { { id: global_id_of(id: non_existing_record_id, model_name: 'Ai::Catalog::Item') } }

      it_behaves_like 'an unsuccessful query'
    end

    context 'when beta features are enabled' do
      let(:current_user) { create(:user, organizations: [current_organization]) }

      before do
        stub_application_setting(instance_level_ai_beta_features_enabled: true)
      end

      it 'returns mcp servers' do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)

        expect(data['latestVersion']['mcpServers']).to match("nodes" => [a_graphql_entity_for(mcp_server)])
      end
    end
  end

  context 'with a private catalog item' do
    let_it_be(:catalog_item, freeze: false) { create(:ai_catalog_item, project: project) }

    it_behaves_like 'an unsuccessful query'

    context 'when the user has permission' do
      let(:current_user) { guest_user }

      it_behaves_like 'a successful query'
    end
  end

  it 'returns the latest version when more than one exists' do
    latest_version = create(:ai_catalog_item_version, version: '2.1.0', item: catalog_item)

    post_graphql(query, current_user: nil)

    expect(response).to have_gitlab_http_status(:success)
    expect(data).to match(
      a_graphql_entity_for(
        catalog_item,
        'latestVersion' => a_graphql_entity_for(latest_version)
      )
    )
  end

  context 'when requesting latestVersion(released: true)' do
    let(:latest_version_data) { graphql_data_at(:ai_catalog_item, :latest_version) }

    let(:query) do
      <<~GRAPHQL
        query {
          aiCatalogItem(id: "#{params[:id]}") {
            latestVersion(released: true) {
              id
            }
          }
        }
      GRAPHQL
    end

    it 'returns nil when there is no latest released version' do
      post_graphql(query, current_user: nil)

      expect(response).to have_gitlab_http_status(:success)
      expect(latest_version_data).to be_nil
    end

    context 'when there is a latest released version' do
      before do
        latest_version.update!(release_date: 1.day.ago)
        catalog_item.update!(latest_released_version: latest_version)
      end

      it 'returns the latest released version' do
        post_graphql(query, current_user: nil)

        expect(response).to have_gitlab_http_status(:success)
        expect(latest_version_data).to match(a_graphql_entity_for(latest_version))
      end
    end
  end

  describe 'configurationForProject field' do
    let_it_be(:item_consumer, freeze: false) { create(:ai_catalog_item_consumer, item: catalog_item, project: project) }

    let_it_be(:item_consumer_for_other_project, freeze: false) do
      create(:ai_catalog_item_consumer,
        item: catalog_item,
        project: create(:project, organization: current_organization)
      )
    end

    let_it_be(:other_item, freeze: false) { create(:ai_catalog_item, organization: current_organization) }

    let_it_be(:item_consumer_for_other_item, freeze: false) do
      create(:ai_catalog_item_consumer, project: project, item: other_item)
    end

    let(:data) { graphql_data_at(:ai_catalog_item, :configuration_for_project) }

    let(:query) do
      <<~GRAPHQL
        query {
          aiCatalogItem(id: "#{params[:id]}") {
            configurationForProject(projectId: "#{project.to_global_id}") {
              id
              enabled
            }
          }
        }
      GRAPHQL
    end

    context 'when the user does not have permission' do
      let(:current_user) { create(:user) }

      it_behaves_like 'an unsuccessful query'
    end

    context 'when the user has permission' do
      let(:current_user) { guest_user }

      it 'returns the item configuration' do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(data).to match(a_graphql_entity_for(item_consumer, :enabled))
      end
    end
  end

  describe 'configurationForGroup field' do
    let_it_be(:group, freeze: false) { create(:group, guests: guest_user, developers: developer_user) }
    let_it_be(:item_consumer, freeze: false) { create(:ai_catalog_item_consumer, item: catalog_item, group: group) }

    let_it_be(:item_consumer_for_other_group, freeze: false) do
      create(:ai_catalog_item_consumer,
        item: catalog_item,
        group: create(:group, organization: current_organization)
      )
    end

    let_it_be(:other_item, freeze: false) { create(:ai_catalog_item, organization: current_organization) }
    let_it_be(:item_consumer_for_other_item, freeze: false) do
      create(:ai_catalog_item_consumer, group: group, item: other_item)
    end

    let(:data) { graphql_data_at(:ai_catalog_item, :configuration_for_group) }

    let(:query) do
      <<~GRAPHQL
        query {
          aiCatalogItem(id: "#{params[:id]}") {
            configurationForGroup(groupId: "#{group.to_global_id}") {
              id
              enabled
            }
          }
        }
      GRAPHQL
    end

    context 'when the user does not have permission' do
      let(:current_user) { create(:user) }

      it_behaves_like 'an unsuccessful query'
    end

    context 'when the user has permission' do
      let(:current_user) { guest_user }

      it 'returns the item configuration' do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(data).to match(a_graphql_entity_for(item_consumer, :enabled))
      end
    end
  end

  describe 'isEnabledInManagedByProject field' do
    let(:data) { graphql_data_at(:ai_catalog_item, :is_enabled_in_managed_by_project) }

    let(:query) do
      <<~GRAPHQL
        query {
          aiCatalogItem(id: "#{params[:id]}") {
            isEnabledInManagedByProject
          }
        }
      GRAPHQL
    end

    context 'when there is no enabled consumer in the managed-by project' do
      it 'returns false' do
        post_graphql(query, current_user: guest_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(data).to be(false)
      end
    end

    context 'when there is an enabled consumer in the managed-by project' do
      before do
        create(:ai_catalog_item_consumer, item: catalog_item, project: project, enabled: true)
      end

      it 'returns true' do
        post_graphql(query, current_user: guest_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(data).to be(true)
      end
    end
  end

  context 'when item is a flow' do
    let_it_be(:flow, freeze: false) { create(:ai_catalog_flow, :public, project: project) }
    let(:params) { { id: flow.to_global_id } }

    it 'returns yaml definition' do
      post_graphql(query, current_user: nil)

      expect(graphql_data_at(:ai_catalog_item, :latest_version, :definition)).to eq(
        flow.latest_version.definition['yaml_definition']
      )
    end
  end

  context 'when item is a foundational chat agent', :saas do
    let_it_be(:catalog_item, freeze: false) do
      create(:ai_catalog_item, :public, project: project, verification_level: :unverified)
    end

    before do
      definition = ::Ai::FoundationalChatAgent.find_by_reference('duo_planner')
      allow(::Ai::FoundationalChatAgent).to receive(:find_by).and_call_original
      allow(::Ai::FoundationalChatAgent).to receive(:find_by)
        .with(global_catalog_id: catalog_item.id).and_return(definition)
    end

    it 'returns the verification level from the definition' do
      post_graphql(query, current_user: nil)

      expect(graphql_data_at(:ai_catalog_item, :verification_level)).to eq('GITLAB_MAINTAINED')
    end
  end

  context 'when item belongs to another organization' do
    let_it_be(:catalog_item, freeze: false) do
      create(:ai_catalog_item, :public, organization: create(:organization))
    end

    it_behaves_like 'an unsuccessful query'
  end

  context 'when item has been soft deleted' do
    let_it_be(:catalog_item, freeze: false) do
      create(:ai_catalog_item, :public, project: project, deleted_at: 1.day.ago)
    end

    context 'when show_soft_deleted is not provided' do
      it_behaves_like 'an unsuccessful query'
    end

    context 'when show_soft_deleted is true' do
      let(:params) { super().merge(show_soft_deleted: true) }

      it_behaves_like 'a successful query'
    end

    context 'when show_soft_deleted is false' do
      let(:params) { super().merge(show_soft_deleted: false) }

      it_behaves_like 'an unsuccessful query'
    end
  end

  describe 'starred field' do
    let(:query) do
      <<~GRAPHQL
        {
          aiCatalogItem(id: "#{catalog_item.to_global_id}") {
            starred
          }
        }
      GRAPHQL
    end

    context 'when the user is not authenticated' do
      it 'returns false' do
        post_graphql(query, current_user: nil)

        expect(graphql_data_at(:ai_catalog_item, :starred)).to be(false)
      end
    end

    context 'when the user has not starred the item' do
      it 'returns false' do
        post_graphql(query, current_user: guest_user)

        expect(graphql_data_at(:ai_catalog_item, :starred)).to be(false)
      end
    end

    context 'when the user has starred the item' do
      before do
        catalog_item.star(guest_user)
      end

      it 'returns true' do
        post_graphql(query, current_user: guest_user)

        expect(graphql_data_at(:ai_catalog_item, :starred)).to be(true)
      end
    end
  end
end
