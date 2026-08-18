# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::Agent::Create, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, :in_group, maintainers: maintainer) }

  let(:current_user) { maintainer }
  let(:mutation) do
    graphql_mutation(:ai_catalog_agent_create, params) do
      <<~FIELDS
        errors
        item {
          id
          name
          description
          project {
            id
          }
          visibility
          latestVersion {
            released
            ... on AiCatalogAgentVersion {
              systemPrompt
              tools {
                nodes {
                  id
                }
              }
              userPrompt
            }
          }
        }
      FIELDS
    end
  end

  let(:name) { 'Name' }
  let(:description) { 'Description' }
  let(:tools) { Ai::Catalog::BuiltInTool.where(id: [1, 9]) }
  let_it_be(:mcp_servers) { create_list(:ai_catalog_mcp_server, 2) }

  let(:params) do
    {
      project_id: project.to_global_id,
      name: name,
      description: description,
      visibility: 'RESTRICTED',
      release: true,
      system_prompt: 'A',
      tools: tools.map { |tool| global_id_of(tool) },
      mcp_servers: mcp_servers.map { |s| global_id_of(s) },
      user_prompt: 'B'
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    enable_ai_catalog
  end

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create a catalog item or version' do
      expect { execute }.not_to change { Ai::Catalog::Item.count }
    end
  end

  context 'when user is a developer' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  context 'when user has a custom role with admin_ai_catalog_item' do
    let_it_be(:group) { create(:group) }
    let_it_be(:custom_role_project) { create(:project, group: group) }
    let_it_be(:custom_role_user) { create(:user) }
    let_it_be(:custom_role) { create(:member_role, :guest, :admin_ai_catalog_item, namespace: group) }
    let_it_be(:custom_role_membership) do
      create(:project_member, :guest, member_role: custom_role, user: custom_role_user, project: custom_role_project)
    end

    let(:current_user) { custom_role_user }
    let(:params) { super().merge(project_id: custom_role_project.to_global_id) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    it 'creates a catalog agent' do
      expect { execute }.to change { Ai::Catalog::Item.count }.by(1)
    end
  end

  context 'when graphql params are invalid' do
    let(:name) { nil }
    let(:description) { nil }

    it 'returns the validation error' do
      execute

      expect(graphql_errors.first['message']).to include(
        'provided invalid value for',
        'name (Expected value to not be null)',
        'description (Expected value to not be null)'
      )
    end
  end

  context 'when model params are invalid' do
    let(:name) { '' }
    let(:description) { '' }

    it 'returns the validation error' do
      execute

      expect(graphql_data_at(:ai_catalog_agent_create, :errors)).to contain_exactly(
        "Description can't be blank",
        "Name can't be blank",
        "Name is too short (minimum is 3 characters)"
      )
      expect(graphql_data_at(:ai_catalog_agent_create, :item)).to be_nil
    end
  end

  it 'creates a catalog item and version with expected data', :freeze_time do
    execute

    item = Ai::Catalog::Item.last

    expect(item).to have_attributes(
      name: params[:name],
      description: params[:description],
      visibility: 'restricted',
      item_type: Ai::Catalog::Item::AGENT_TYPE.to_s
    )
    expect(item.latest_version).to have_attributes(
      schema_version: 1,
      release_date: Time.zone.now,
      version: '1.0.0',
      definition: {
        system_prompt: params[:system_prompt],
        tools: tools.map(&:id),
        mcp_tools: [],
        mcp_servers: mcp_servers.map(&:id),
        user_prompt: params[:user_prompt]
      }.stringify_keys
    )
  end

  it 'returns the new item' do
    execute

    expect(graphql_data_at(:ai_catalog_agent_create, :item)).to match a_hash_including(
      'name' => name,
      'description' => description,
      'project' => a_graphql_entity_for(project),
      'visibility' => 'RESTRICTED',
      'latestVersion' => {
        'released' => true,
        'systemPrompt' => params[:system_prompt],
        'tools' => {
          'nodes' => match_array(
            tools.map { |tool| a_graphql_entity_for(tool) }
          )
        },
        'userPrompt' => params[:user_prompt]
      }
    )
  end

  context 'when tools argument is missing' do
    let(:params) { super().except(:tools) }

    it 'creates an agent with empty tools array' do
      execute

      item = Ai::Catalog::Item.last

      expect(item.latest_version.definition['tools']).to eq([])
    end
  end

  context 'when passing only required arguments (test that mutation handles absence of optional args)' do
    let(:params) { super().except(:release, :tools, :user_prompt) }

    it 'works without errors' do
      execute

      expect(graphql_data_at(:ai_catalog_agent_create, :errors)).to be_empty
    end

    it 'returns a new item with all required arguments' do
      execute

      expect(graphql_data_at(:ai_catalog_agent_create, :item)).to match a_hash_including(
        'name' => name,
        'description' => description,
        'project' => a_graphql_entity_for(project),
        'visibility' => 'RESTRICTED',
        'latestVersion' => {
          'released' => true,
          'systemPrompt' => params[:system_prompt],
          'tools' => { 'nodes' => [] },
          'userPrompt' => ""
        }
      )
    end
  end

  context 'when mcp_tools are provided' do
    let(:params) { super().merge(mcp_tools: %w[search create_issue]) }
    let(:mcp_tools_mutation) do
      graphql_mutation(:ai_catalog_agent_create, params) do
        <<~FIELDS
          errors
          item {
            latestVersion {
              ... on AiCatalogAgentVersion {
                mcpTools
              }
            }
          }
        FIELDS
      end
    end

    it 'creates an agent with mcp_tools in the definition' do
      execute

      item = Ai::Catalog::Item.last

      expect(item.latest_version.definition['mcp_tools']).to match_array(%w[search create_issue])
    end

    it 'returns mcpTools in the GraphQL response' do
      post_graphql_mutation(mcp_tools_mutation, current_user: current_user)

      mcp_tools = graphql_data_at(:ai_catalog_agent_create, :item, :latest_version, :mcp_tools)
      expect(mcp_tools).to match_array(%w[search create_issue])
    end
  end

  context 'when mcp_tools argument is missing' do
    let(:params) { super().except(:mcp_tools) }

    it 'creates an agent with empty mcp_tools array' do
      execute

      item = Ai::Catalog::Item.last

      expect(item.latest_version.definition['mcp_tools']).to eq([])
    end
  end

  context 'when mcp_servers argument is missing' do
    let(:params) { super().except(:mcp_servers) }

    it 'creates an agent with empty mcp_servers array' do
      execute

      item = Ai::Catalog::Item.last
      expect(item.latest_version.definition['mcp_servers']).to eq([])
    end
  end

  context 'when using the legacy public argument' do
    let(:params) { super().except(:visibility).merge(public: true) }

    it 'creates an agent with public visibility' do
      execute

      expect(Ai::Catalog::Item.last).to have_attributes(visibility: 'public')
      expect(graphql_data_at(:ai_catalog_agent_create, :item, :visibility)).to eq('PUBLIC')
    end
  end

  it_behaves_like 'an AI catalog create mutation with a visibility argument' do
    let(:mutation_name) { :ai_catalog_agent_create }
  end
end
