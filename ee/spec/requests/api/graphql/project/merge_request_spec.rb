# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting merge request information nested in a project', feature_category: :code_review_workflow do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, :public) }

  let(:merge_request) { create(:merge_request, source_project: project) }
  let(:merge_request_graphql_data) { graphql_data_at(:project, :merge_request) }
  let(:mr_fields) { "suggestedReviewers { #{all_graphql_fields_for('SuggestedReviewersType')} }" }
  let(:suggested_reviewers) do
    {
      'version' => '0.0.0',
      'top_n' => 1,
      'reviewers' => %w[bmarley swayne]
    }
  end

  let(:accepted_reviewers) do
    {
      'reviewers' => %w[bmarley]
    }
  end

  let(:api_result) do
    {
      'accepted' => %w[bmarley],
      'suggested' => %w[bmarley swayne]
    }
  end

  let(:query) do
    graphql_query_for(
      :project,
      { full_path: project.full_path },
      query_graphql_field(:merge_request, { iid: merge_request.iid.to_s }, mr_fields)
    )
  end

  describe 'suggestedReviewers' do
    before do
      merge_request.build_predictions
      merge_request.predictions.update!(
        suggested_reviewers: suggested_reviewers,
        accepted_reviewers: accepted_reviewers
      )
      allow_any_instance_of(Project) # rubocop:disable RSpec/AnyInstanceOf
        .to receive(:can_suggest_reviewers?).and_return(available)
    end

    shared_examples 'feature available' do
      it 'returns the right suggested reviewers' do
        post_graphql(query, current_user: current_user)

        expected_data = {
          'suggestedReviewers' => a_hash_including(api_result)
        }

        expect(merge_request_graphql_data).to include(expected_data)
      end
    end

    shared_examples 'feature unavailable' do
      it 'returns nil' do
        post_graphql(query, current_user: current_user)

        expected_data = {
          'suggestedReviewers' => nil
        }

        expect(merge_request_graphql_data).to include(expected_data)
      end
    end

    context 'when suggested reviewers is available for the project' do
      let(:available) { true }

      include_examples 'feature available'
    end

    context 'when suggested reviewers is not available for the project' do
      let(:available) { false }

      include_examples 'feature unavailable'
    end
  end

  describe 'duoWorkflows' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :repository, :public, group: group) }
    let_it_be(:current_user) { create(:user, developer_of: group) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:duo_workflow) do
      create(:duo_workflows_workflow, project: project, user: current_user, merge_request: merge_request)
    end

    let(:mr_fields) do
      <<~GRAPHQL
        duoWorkflows {
          nodes {
            id
          }
        }
      GRAPHQL
    end

    context 'when ai_workflows feature is licensed' do
      before do
        stub_licensed_features(ai_workflows: true)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        allow_any_instance_of(User).to receive(:allowed_to_use).and_return( # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
          Ai::UserAuthorizable::Response.new(allowed?: true, namespace_ids: [group.id])
        )

        post_graphql(query, current_user: current_user)
      end

      it 'returns duo workflows' do
        expect(merge_request_graphql_data).to include(
          'duoWorkflows' => {
            'nodes' => [
              { 'id' => duo_workflow.to_gid.to_s }
            ]
          }
        )
      end
    end

    context 'when ai_workflows feature is unlicensed' do
      before do
        stub_licensed_features(ai_workflows: false)

        post_graphql(query, current_user: current_user)
      end

      it 'returns nil' do
        expect(merge_request_graphql_data['duoWorkflows']).to be_nil
      end
    end
  end
end
