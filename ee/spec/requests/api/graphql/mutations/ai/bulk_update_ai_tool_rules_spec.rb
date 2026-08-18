# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'BulkUpdateAiToolRules', feature_category: :ai_agents do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:owner) { create(:user, owner_of: group) }

  let(:current_user) { owner }
  let(:input) do
    { full_path: group.full_path, tool_rules: [{ tool_id: 'create_issue', web_access: :ASK }] }
  end

  let(:mutation) { graphql_mutation(:bulk_update_ai_tool_rules, input, 'errors results { toolId errors }') }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  it 'bulk updates the tool rules' do
    post_mutation

    response = graphql_mutation_response(:bulk_update_ai_tool_rules)
    expect(response['errors']).to be_empty
    expect(response['results'].length).to eq(1)
    expect(response['results'].first).to include('toolId' => 'create_issue', 'errors' => [])
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :update_ai_tool_rule do
    let(:user) { owner }
    let(:boundary_object) { group }
    let(:mutation) { graphql_mutation(:bulk_update_ai_tool_rules, input, 'errors') }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end
end
