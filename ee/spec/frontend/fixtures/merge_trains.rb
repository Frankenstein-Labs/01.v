# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "GraphQL Merge Trains", '(JavaScript fixtures)', type: :request, feature_category: :pipeline_composition do
  include ApiHelpers
  include GraphqlHelpers
  include JavaScriptFixturesHelpers
  include MergeTrainsHelpers

  let(:project) { create(:project, :repository) }
  let(:user) { project.first_owner }
  let(:reporter) { create(:user) }

  let(:active_query_path) { 'ci/merge_trains/graphql/queries/get_active_merge_trains.query.graphql' }
  let(:completed_query_path) { 'ci/merge_trains/graphql/queries/get_completed_merge_trains.query.graphql' }

  before do
    stub_licensed_features(merge_trains: true)
    project.add_reporter(reporter)
  end

  context 'with active car' do
    let!(:merge_request) { create_merge_request_on_train(project: project) }
    let(:train_car) { merge_request.merge_train_car }

    before do
      train_car.update!(pipeline: create(:ci_pipeline, project: train_car.project))
    end

    it "ee/graphql/merge_trains/active_merge_trains.json" do
      query = get_graphql_query_as_string(active_query_path, ee: true)

      post_graphql(query,
        current_user: user,
        variables: { fullPath: project.full_path, targetBranch: 'master' })

      expect_graphql_errors_to_be_empty
    end
  end

  context 'with merged car' do
    let!(:merge_request) do
      create_merge_request_on_train(project: project, source_branch: 'feature-2', status: :merged)
    end

    let(:train_car) { merge_request.merge_train_car }

    before do
      train_car.update!(pipeline: create(:ci_pipeline, project: train_car.project), merged_at: 5.days.ago)
    end

    it "ee/graphql/merge_trains/completed_merge_trains.json" do
      query = get_graphql_query_as_string(completed_query_path, ee: true)

      post_graphql(query,
        current_user: user,
        variables: { fullPath: project.full_path, targetBranch: 'master', status: 'COMPLETED' })

      expect_graphql_errors_to_be_empty
    end
  end

  context 'without delete car permissions' do
    let!(:merge_request) { create_merge_request_on_train(project: project) }
    let(:train_car) { merge_request.merge_train_car }

    before do
      train_car.update!(pipeline: create(:ci_pipeline, project: train_car.project))
    end

    it "ee/graphql/merge_trains/active_merge_trains_guest.json" do
      query = get_graphql_query_as_string(active_query_path, ee: true)

      post_graphql(query,
        current_user: reporter,
        variables: { fullPath: project.full_path, targetBranch: 'master' })

      expect_graphql_errors_to_be_empty
    end
  end
end
