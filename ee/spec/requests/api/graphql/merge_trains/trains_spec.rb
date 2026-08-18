# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project.mergeTrains.cars', feature_category: :merge_trains do
  include GraphqlHelpers
  include MergeTrainsHelpers

  let_it_be_with_reload(:private_project) { create(:project, :repository) }
  let(:target_project) { private_project }
  let(:car_fields) do
    <<~QUERY
      nodes {
        mergeRequest {
          title
        }
        pipeline {
          status
        }
        userPermissions {
          deleteMergeTrainCar
        }
        #{all_graphql_fields_for('MergeTrainCar', max_depth: 1)}
      }
    QUERY
  end

  let(:train_fields) do
    <<~QUERY
      nodes {
        targetBranch
        #{car_query}
      }
    QUERY
  end

  let(:car_query) do
    query_graphql_field(
      :cars,
      car_params,
      car_fields
    )
  end

  let(:train_query) do
    query_graphql_field(
      :merge_trains,
      params,
      train_fields
    )
  end

  let_it_be(:reporter) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let(:query) { graphql_query_for(:project, { full_path: target_project.full_path }, train_query) }
  let(:user) { reporter }
  let(:params) { { status: ::MergeTrains::Train::STATUSES[:active].upcase.to_sym } }
  let(:car_params) { {} }
  let(:post_query) { post_graphql(query, current_user: user) }
  let(:data) { graphql_data }

  subject(:result) { graphql_data_at(:project, :merge_trains, :nodes, :target_branch) }

  before do
    stub_licensed_features(merge_trains: true)
  end

  before_all do
    private_project.ci_cd_settings.update!(merge_trains_enabled: true)
    private_project.add_reporter(reporter)
    private_project.add_guest(guest)
    private_project.add_maintainer(maintainer)
    create_merge_request_on_train(project: private_project, author: maintainer)
    create_merge_request_on_train(project: private_project, source_branch: 'branch-1', author: maintainer)
    create_merge_request_on_train(project: private_project, source_branch: 'branch-2', status: :merged,
      author: maintainer)
    create_merge_request_on_train(project: private_project, target_branch: 'feature-1', author: maintainer)
    create_merge_request_on_train(project: private_project, target_branch: 'feature-2', status: :merged,
      author: maintainer)
    create(:merge_train_car, target_project: create(:project), target_branch: 'master')
  end

  shared_examples 'fetches the requested trains' do
    before do
      post_query
    end

    it 'returns relevant merge trains' do
      expect(result).to contain_exactly(*expected_branches)
    end

    it 'does not have N+1 problem', :use_sql_query_cache do
      # warm up the query to avoid flakiness
      run_query

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { run_query }

      create_merge_request_on_train(project: target_project, source_branch: 'branch-7', author: maintainer)
      create_merge_request_on_train(project: target_project, source_branch: 'branch-6', target_branch: 'feature-1',
        author: maintainer)

      expect { run_query }.to issue_same_number_of_queries_as(control)
    end
  end

  context 'when the user does not have the permissions' do
    let(:user) { guest }

    it 'returns an empty array without errors' do
      post_query

      expect(graphql_errors).to be_blank
      expect(result).to eq([])
    end
  end

  context 'when the project does not have the required license' do
    let(:result) { graphql_data_at(:project, :merge_trains, :nodes, :cars, :nodes) }

    before do
      stub_licensed_features(merge_trains: false)

      create_merge_request_on_train(project: target_project, source_branch: 'branch-4', author: maintainer)
    end

    it 'returns nil' do
      post_query
      expect(result).to be_nil
    end
  end

  context 'when logged out' do
    let(:user) { nil }

    context 'with a public project' do
      let_it_be_with_reload(:public_project) { create(:project, :public) }
      let(:target_project) { public_project }

      before_all do
        public_project.ci_cd_settings.update!(merge_trains_enabled: true)
        create_merge_request_on_train(project: public_project, author: maintainer)
        create_merge_request_on_train(project: public_project, target_branch: 'feature-1', author: maintainer)
      end

      it_behaves_like 'fetches the requested trains' do
        let(:expected_branches) { %w[master feature-1] }

        before do
          public_project.project_feature.update!(merge_requests_access_level: ProjectFeature::ENABLED)
        end
      end

      context 'when merge request access level is PRIVATE' do
        it 'returns an empty array without errors' do
          public_project.project_feature.update!(merge_requests_access_level: ProjectFeature::PRIVATE)

          post_query

          expect(graphql_errors).to be_blank
          expect(result).to eq([])
        end
      end
    end

    context 'with a private project' do
      it 'returns nil for project' do
        post_query

        expect(graphql_data_at(:project)).to be_nil
      end
    end
  end

  context 'when the user has the right permissions' do
    context 'when only the project is provided' do
      it_behaves_like 'fetches the requested trains' do
        let(:expected_branches) { %w[master feature-1] }
      end
    end

    context 'when target_branches are provided' do
      let(:params) do
        {
          target_branches: %w[feature-1 feature-2],
          status: ::MergeTrains::Train::STATUSES[:active].upcase.to_sym
        }
      end

      it_behaves_like 'fetches the requested trains' do
        let(:expected_branches) { %w[feature-1] }
      end

      context 'when status is provided' do
        before do
          params[:status] = ::MergeTrains::Train::STATUSES[:completed].upcase.to_sym
        end

        it_behaves_like 'fetches the requested trains' do
          let(:expected_branches) { %w[feature-2] }
        end
      end
    end

    context 'when train status is provided' do
      let(:params) { { status: ::MergeTrains::Train::STATUSES[:completed].upcase.to_sym } }

      it_behaves_like 'fetches the requested trains' do
        let(:expected_branches) { %w[feature-2] }
      end
    end

    context 'when car params are provided' do
      let(:result) { graphql_data_at(:project, :merge_trains, :nodes, :cars, :nodes) }

      before do
        create_merge_request_on_train(project: target_project, source_branch: 'branch-4', author: maintainer)
        create_merge_request_on_train(project: target_project, source_branch: 'branch-5', status: :merged,
          author: maintainer)
        create_merge_request_on_train(project: target_project, source_branch: 'branch-6', status: :merged,
          author: maintainer)
      end

      it 'fetches the active cars for each train' do
        post_query
        result.each do |car|
          expect(car['status']).to eq('IDLE')
        end
      end

      context 'when the user has delete permissions' do
        let(:user) { maintainer }

        it 'deleteMergeTrainCar is true' do
          post_query
          result.each do |car|
            expect(car.dig('userPermissions', 'deleteMergeTrainCar')).to be(true)
          end
        end
      end

      context 'when the user does not have delete permissions' do
        let(:user) { reporter }

        it 'deleteMergeTrainCar is false' do
          post_query
          result.each do |car|
            expect(car.dig('userPermissions', 'deleteMergeTrainCar')).to be(false)
          end
        end
      end

      context 'when the status is COMPLETED' do
        let(:car_params) { { activity_status: :COMPLETED } }

        it 'fetches the first completed cars for each train' do
          post_query
          result.each { |car| expect(car['status']).to eq('MERGED') }
        end
      end
    end
  end

  private

  def run_query
    post_graphql(query, current_user: user)
  end
end
