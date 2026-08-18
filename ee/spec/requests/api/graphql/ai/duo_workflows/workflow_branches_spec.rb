# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying the branches of a Duo Agent Platform turn', feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be(:another_user) { create(:user, developer_of: group) }

  let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }

  let(:current_user) { user }
  let(:query) do
    graphql_query_for(
      'duoWorkflowBranches',
      { workflow_id: workflow.to_global_id.to_s, thread_ts: 'ts-1' },
      <<~GRAPHQL
        forkThreadTs
        messages { content }
      GRAPHQL
    )
  end

  subject(:branches) { graphql_data['duoWorkflowBranches'] }

  before do
    # read_duo_workflow needs :duo_workflow on the project, which checks the stage and
    # the user's seat; ownership of the session is what the policy narrows on.
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(any_args).and_return(true)
    # rubocop:disable RSpec/AnyInstanceOf -- the users already exist, so not the next instance
    allow_any_instance_of(User).to receive_messages(allowed_to_use?: true, allowed_to_use_for_resource?: true)
    # rubocop:enable RSpec/AnyInstanceOf
  end

  it 'answers with no branches until they are reconstructed', :aggregate_failures do
    post_graphql(query, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(graphql_errors).to be_nil
    expect(branches).to eq([])
  end

  # The read that fills the field in authorizes the session; until then there is
  # nothing to withhold, so every caller sees the same empty list.
  context 'when the user cannot read the session' do
    let(:current_user) { another_user }

    it 'answers with no branches' do
      post_graphql(query, current_user: current_user)

      expect(branches).to eq([])
    end
  end

  context 'when the user is not logged in' do
    it 'answers with no branches' do
      post_graphql(query, current_user: nil)

      expect(branches).to eq([])
    end
  end
end
