# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).pipelines.duoWorkflows', feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:current_user) { create(:user, developer_of: group) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

  let(:pipelines_query) do
    %(
      query {
        project(fullPath: "#{project.full_path}") {
          pipelines {
            nodes {
              id
              duoWorkflows {
                nodes {
                  id
                }
              }
            }
          }
        }
      }
    )
  end

  let(:pipeline_query) do
    %(
      query {
        project(fullPath: "#{project.full_path}") {
          pipeline(iid: "#{pipeline.iid}") {
            duoWorkflows {
              nodes {
                id
              }
            }
          }
        }
      }
    )
  end

  before do
    stub_licensed_features(ai_workflows: true)
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
    allow_any_instance_of(User).to receive(:allowed_to_use).and_return( # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
      Ai::UserAuthorizable::Response.new(allowed?: true, namespace_ids: [group.id])
    )
  end

  # A pipeline collects sessions from whoever triggered them, so each workflow gets its own
  # user: that keeps the owner check on the policy path a distinct query per node if it runs.
  def create_linked_workflow(pipeline, user: create(:user))
    create(:duo_workflows_workflow, user: user, project: project, environment: :web).tap do |workflow|
      create(:duo_workflows_workflow_pipeline, workflow: workflow, pipeline: pipeline)
    end
  end

  it 'returns the workflows linked to each pipeline in the list' do
    workflow = create_linked_workflow(pipeline)
    other_pipeline = create(:ci_pipeline, project: project)
    other_workflow = create_linked_workflow(other_pipeline)

    post_graphql(pipelines_query, current_user: current_user)

    workflow_ids = graphql_data_at(:project, :pipelines, :nodes).map do |node|
      node.dig('duoWorkflows', 'nodes').pluck('id')
    end

    expect(workflow_ids).to contain_exactly([other_workflow.to_gid.to_s], [workflow.to_gid.to_s])
  end

  # skip_cached: false, because a per-node project load repeats identical SQL and would
  # otherwise be hidden by the query cache.
  it 'avoids N+1 queries as more pipelines with workflows are added', :request_store, :use_sql_query_cache do
    create_linked_workflow(pipeline)

    post_graphql(pipelines_query, current_user: current_user)

    control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
      post_graphql(pipelines_query, current_user: current_user)
    end

    2.times { create_linked_workflow(create(:ci_pipeline, project: project)) }

    expect do
      post_graphql(pipelines_query, current_user: current_user)
    end.not_to exceed_all_query_limit(control)
  end

  it 'avoids N+1 queries as more workflows are linked to one pipeline', :request_store, :use_sql_query_cache do
    create_linked_workflow(pipeline)

    post_graphql(pipeline_query, current_user: current_user)

    control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
      post_graphql(pipeline_query, current_user: current_user)
    end

    2.times { create_linked_workflow(pipeline) }

    expect do
      post_graphql(pipeline_query, current_user: current_user)
    end.not_to exceed_all_query_limit(control)
  end
end
