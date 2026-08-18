# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'UpdateAiToolRule', feature_category: :ai_agents do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:owner) { create(:user, owner_of: group) }

  let(:current_user) { owner }
  let(:input) { { full_path: group.full_path, tool_id: 'create_issue', web_access: :ASK } }
  let(:mutation) { graphql_mutation(:update_ai_tool_rule, input, 'errors toolRule { id webAccess }') }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  it 'updates the tool rule' do
    post_mutation

    response = graphql_mutation_response(:update_ai_tool_rule)
    expect(response['errors']).to be_empty
    expect(response['toolRule']).to include('id' => 'create_issue', 'webAccess' => 'ASK')
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :update_ai_tool_rule do
    let(:user) { owner }
    let(:boundary_object) { group }
    let(:mutation) { graphql_mutation(:update_ai_tool_rule, input, 'errors') }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end
end
