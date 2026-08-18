# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeTrains::CarPolicy, feature_category: :merge_trains do
  include MergeTrainsHelpers

  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  let_it_be(:car) do
    create(:merge_train_car, target_project: project, target_branch: 'master')
  end

  subject(:policy) { described_class.new(user, car) }

  it 'is disallowed when user has no access to project' do
    is_expected.to be_disallowed(:read_merge_train_car)
    is_expected.to be_disallowed(:delete_merge_train_car)
  end

  context 'when user is permitted to read merge request' do
    before_all do
      project.add_reporter(user)
    end

    it { is_expected.to be_allowed(:read_merge_train_car) }
    it { is_expected.to be_disallowed(:delete_merge_train_car) }
  end

  context 'when user is permitted to update the merge_request and cancel the pipeline' do
    let_it_be(:car) do
      create_merge_request_on_train(project: project, source_branch: 'feature', author: user).merge_train_car
    end

    before_all do
      project.add_developer(user)
    end

    it { is_expected.to be_allowed(:delete_merge_train_car) }
  end
end
