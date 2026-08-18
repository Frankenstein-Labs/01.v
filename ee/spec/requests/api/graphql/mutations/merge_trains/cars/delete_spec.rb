# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Deleting a MergeTrain Car', feature_category: :merge_trains do
  include GraphqlHelpers
  include MergeTrainsHelpers

  let_it_be_with_reload(:target_project) { create(:project, :repository) }
  let_it_be(:developer) { create(:user, developer_of: target_project) }
  let_it_be(:reporter) { create(:user, reporter_of: target_project) }
  let_it_be(:guest) { create(:user, guest_of: target_project) }
  let(:query) { graphql_query_for(:project, { full_path: target_project.full_path }, train_query) }
  let(:user) { reporter }
  let(:target_car) do
    create_merge_request_on_train(project: target_project, author: developer, source_branch: 'feature-1')
      .merge_train_car
  end

  let!(:target_car_id) do
    target_car.to_gid
  end

  let(:mutation) do
    graphql_mutation(:merge_trains_delete_car, { car_id: target_car_id }, 'errors')
  end

  let(:mutation_response) { graphql_mutation_response(:merge_trains_delete_car) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: user) }

  before do
    stub_licensed_features(merge_trains: true)
  end

  before_all do
    target_project.ci_cd_settings.update!(merge_trains_enabled: true)
    create_merge_request_on_train(project: target_project, author: developer)
  end

  context 'when the user does not have the permissions' do
    let(:user) { guest }

    it 'returns a resource not available error' do
      post_mutation
      expect_graphql_errors_to_include(
        "The resource that you are attempting to access does not exist " \
          "or you don't have permission to perform this action"
      )
    end
  end

  context 'when the project does not have the required license' do
    before do
      stub_licensed_features(merge_trains: false)
    end

    it 'returns a resource not available error' do
      post_mutation
      expect_graphql_errors_to_include(
        "The resource that you are attempting to access does not exist " \
          "or you don't have permission to perform this action"
      )
    end
  end

  context 'when the user has the right permissions' do
    let(:user) { developer }

    it 'deletes the requested car' do
      expect { post_mutation }.to change { MergeTrains::Car.count }.by(-1)
      expect(MergeTrains::Car.find_by(id: target_car.id)).to be_nil
      expect_graphql_errors_to_be_empty
    end

    context 'when the service returns an error' do
      let(:current_user) { user }

      before do
        allow_next_found_instance_of(MergeTrains::Car) do |car|
          allow(car).to receive(:destroy).and_raise(StandardError)
        end
      end

      it_behaves_like 'a mutation that returns errors in the response',
        errors: ["Can't cancel the automatic merge"]

      it 'does not change the record count' do
        expect { post_mutation }.to not_change { MergeTrains::Car.count }
      end
    end

    context 'when the car does not exist' do
      let(:target_car_id) { build(:merge_train_car, id: non_existing_record_iid).to_gid }

      it 'returns a resource not available error' do
        post_mutation
        expect_graphql_errors_to_include(
          "The resource that you are attempting to access does not exist " \
            "or you don't have permission to perform this action"
        )
      end
    end
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_merge_train_car do
    let(:user) { developer }
    let(:boundary_object) { target_project }

    let(:target_car) do
      create_merge_request_on_train(project: target_project, author: developer, source_branch: 'feature-1')
        .merge_train_car
    end

    let(:mutation) do
      graphql_mutation(:merge_trains_delete_car, { car_id: target_car.to_gid }, 'errors')
    end

    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end
end
