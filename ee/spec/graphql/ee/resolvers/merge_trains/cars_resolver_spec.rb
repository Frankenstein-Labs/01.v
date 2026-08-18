# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::MergeTrains::CarsResolver, feature_category: :merge_trains do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let_it_be(:merge_request) do
    create(:merge_request, :on_train, source_project: project, target_project: project)
  end

  let(:train) { MergeTrains::Train.new(project.id, merge_request.target_branch) }

  describe '#resolve_with_lookahead' do
    context 'when activity_status is active' do
      it 'returns active indexed cars' do
        result = batch_sync do
          resolve(described_class, obj: train, args: { activity_status: 'active' }, ctx: { current_user: user })
        end

        expect(result).to be_present
      end
    end

    context 'when activity_status is completed' do
      let_it_be(:merged_car) do
        create(:merge_train_car, :merged, target_project: project, target_branch: merge_request.target_branch)
      end

      it 'returns completed cars' do
        result = batch_sync do
          resolve(described_class, obj: train, args: { activity_status: 'completed' }, ctx: { current_user: user })
        end

        expect(result).to be_present
      end
    end
  end
end
