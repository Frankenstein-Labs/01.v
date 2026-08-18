# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeTrains::TrainPolicy, feature_category: :merge_trains do
  let_it_be_with_reload(:project) { create(:project, :small_repo) }
  let_it_be(:user) { create(:user) }
  # `freeze: false` required: MergeTrains::Train is a plain value object (not an
  # ActiveRecord model, so reload/refind don't apply). TrainPolicy's
  # `delegate { @subject.project }` rule strong_memoizes on the train via
  # instance_variable_set, which raises FrozenError on a frozen object.
  let_it_be(:train, freeze: false) do
    create(:merge_train_car, target_project: project, target_branch: 'master').train
  end

  subject(:policy) { described_class.new(user, train) }

  context 'when user has no access to project' do
    context 'when the user is not a member' do
      it 'is disallowed' do
        is_expected.to be_disallowed(:read_merge_train)
      end
    end

    context 'when the user is a guest' do
      before_all do
        project.add_guest(user)
      end

      it 'is disallowed' do
        is_expected.to be_disallowed(:read_merge_train)
      end
    end
  end

  context 'when user is permitted to read merge request' do
    before_all do
      project.add_reporter(user)
    end

    it { is_expected.to be_allowed(:read_merge_train) }
  end
end
