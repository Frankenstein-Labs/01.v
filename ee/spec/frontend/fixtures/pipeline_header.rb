# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "GraphQL Pipeline Header", '(JavaScript fixtures)', type: :request, feature_category: :pipeline_composition do
  include ApiHelpers
  include GraphqlHelpers
  include JavaScriptFixturesHelpers

  let_it_be(:namespace, freeze: false) { create(:namespace, name: 'frontend-fixtures') }
  let_it_be(:project, freeze: false) { create(:project, :public, :repository) }
  let_it_be(:user, freeze: false) { project.first_owner }
  let_it_be(:commit, freeze: false) { create(:commit, project: project) }

  let(:query_path) { 'ci/pipeline_details/header/graphql/queries/get_pipeline_header_data.query.graphql' }

  context 'with successful pipeline and compute minutes' do
    let_it_be(:pipeline, freeze: false) do
      create(
        :ci_pipeline,
        project: project,
        sha: commit.id,
        ref: 'master',
        user: user,
        name: 'Build pipeline',
        status: :success,
        duration: 7210,
        created_at: 2.hours.ago,
        started_at: 1.hour.ago,
        finished_at: Time.current
      )
    end

    it "graphql/pipelines/pipeline_header_compute_minutes.json" do
      allow_next_found_instance_of(Ci::Pipeline) do |pipeline|
        allow(pipeline).to receive(:total_ci_minutes_consumed).and_return 25
      end

      query = get_graphql_query_as_string(query_path)

      post_graphql(query, current_user: user, variables: { fullPath: project.full_path, iid: pipeline.iid })

      expect_graphql_errors_to_be_empty
    end
  end
end
