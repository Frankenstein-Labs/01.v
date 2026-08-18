# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting an AI foundational chat agent', feature_category: :workflow_catalog do
  include GraphqlHelpers

  let(:default_organization) { create(:organization) }

  let(:query) do
    <<~GQL
      query($reference: String!) {
        aiFoundationalChatAgent(reference: $reference) {
          id
          name
          reference
          systemPrompt
          tools {
            id
            title
            description
          }
        }
      }
    GQL
  end

  it 'returns the foundational chat agent with that reference' do
    post_graphql(query, current_user: nil, variables: { reference: 'duo_planner' })

    expect(response).to have_gitlab_http_status(:success)

    agent = graphql_data_at('aiFoundationalChatAgent')

    expect(agent["id"]).to eq("gid://gitlab/Ai::FoundationalChatAgent/duo_planner-v1")
    expect(agent["name"]).to eq("Planner")
    expect(agent["reference"]).to eq("duo_planner")
    expect(agent["tools"].first).to include("id", "title", "description")
    expect(agent["systemPrompt"]).to be_a(String)
  end

  context 'when the reference does not match any agent' do
    it 'returns null' do
      post_graphql(query, current_user: nil, variables: { reference: 'nonexistent_agent' })

      expect(response).to have_gitlab_http_status(:success)

      agent = graphql_data_at('aiFoundationalChatAgent')

      expect(agent).to be_nil
    end
  end
end
