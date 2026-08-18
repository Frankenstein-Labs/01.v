# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeTrains::UnstickStuckMergesCronWorker, feature_category: :merge_trains do
  let(:worker) { described_class.new }

  describe '#perform' do
    let_it_be(:project) { create(:project, :repository) }

    subject(:perform) { worker.perform }

    context 'when there are no stuck cars' do
      it 'does not enqueue any refresh workers' do
        expect(MergeTrains::RefreshWorker).not_to receive(:perform_async)

        perform
      end
    end

    context 'when stuck cars exist' do
      let(:merge_request) do
        create(:merge_request, :locked,
          target_project: project,
          source_project: project
        )
      end

      let!(:car) do
        create(:merge_train_car, :merging,
          merge_request: merge_request,
          target_project: project,
          updated_at: 3.hours.ago
        )
      end

      before do
        allow(::MergeTrains::Car).to receive(:stuck_cars).and_return(::MergeTrains::Car.where(id: car.id))
      end

      it 'enqueues a RefreshWorker for each stuck car' do
        expect(MergeTrains::RefreshWorker).to receive(:perform_async)
          .with(car.target_project_id, car.target_branch)

        perform
      end
    end

    context 'when multiple stuck cars exist' do
      let(:mr_1) do
        create(:merge_request, :locked,
          target_project: project,
          source_project: project,
          source_branch: 'improve/awesome',
          target_branch: 'master'
        )
      end

      let(:mr_2) do
        create(:merge_request, :locked,
          target_project: project,
          source_project: project,
          source_branch: 'feature',
          target_branch: 'master'
        )
      end

      let!(:car_1) do
        create(:merge_train_car, :merging,
          merge_request: mr_1,
          target_project: project,
          target_branch: 'master',
          updated_at: 3.hours.ago
        )
      end

      let!(:car_2) do
        create(:merge_train_car, :merging,
          merge_request: mr_2,
          target_project: project,
          target_branch: 'master',
          updated_at: 3.hours.ago
        )
      end

      before do
        allow(::MergeTrains::Car).to receive(:stuck_cars)
          .and_return(::MergeTrains::Car.where(id: [car_1.id, car_2.id]))
      end

      it 'enqueues a RefreshWorker just once for the same target branch and project' do
        expect(MergeTrains::RefreshWorker).to receive(:perform_async)
          .with(project.id, 'master').once

        perform
      end
    end
  end
end
