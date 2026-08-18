# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting AI foundational chat agents', feature_category: :workflow_catalog do
  include GraphqlHelpers

  let(:default_organization) { create(:organization) }
  let(:nodes) { graphql_data_at(:ai_foundational_chat_agents, :nodes) }

  let(:query) do
    "{ #{query_nodes('AiFoundationalChatAgents', max_depth: 2)} }"
  end

  before do
    allow(::Organizations::Organization).to receive(:default_organization).and_return(default_organization)
  end

  it 'returns all foundational chat agents sorted by id', :aggregate_failures do
    post_graphql(query, current_user: nil)

    expect(response).to have_gitlab_http_status(:success)
    expect(nodes).to have_attributes(size: ::Ai::FoundationalChatAgent.count)

    first_node = nodes.first

    expect(first_node["id"]).to eq("gid://gitlab/Ai::FoundationalChatAgent/chat")
    expect(first_node["name"]).to eq("GitLab Duo")
    expect(first_node["reference"]).to eq("chat")
    expect(first_node["referenceWithVersion"]).to eq("chat")
    expect(first_node["version"]).to eq("")
    expect(first_node["avatarUrl"]).to match_asset_path("/bot_avatars/gitlab-duo-agent.png")
    expect(first_node["flowConfig"]).to eq(
      "flowConfigId" => "chat",
      "flowConfigSchemaVersion" => nil,
      "flowVersion" => "^1.0.0"
    )
  end

  it 'returns null flow_config for foundational agents without a flow_version', :aggregate_failures do
    post_graphql(query, current_user: nil)

    catalog_backed = nodes.find { |n| n["reference"] == "duo_planner" }

    expect(catalog_backed).not_to be_nil
    expect(catalog_backed["flowConfig"]).to be_nil
  end
end
