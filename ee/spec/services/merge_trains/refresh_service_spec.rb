# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeTrains::RefreshService, feature_category: :merge_trains do
  include ExclusiveLeaseHelpers

  let(:project) { create(:project) }
  let_it_be(:maintainer_1) { create(:user) }
  let_it_be(:maintainer_2) { create(:user) }

  let(:service) { described_class.new(merge_request.target_project_id, merge_request.target_branch) }

  before do
    project.add_maintainer(maintainer_1)
    project.add_maintainer(maintainer_2)
  end

  describe '#execute', :clean_gitlab_redis_queues do
    subject { service.execute }

    let!(:merge_request_1) do
      create(:merge_request, :on_train,
        train_creator: maintainer_1,
        source_branch: 'feature', source_project: project,
        target_branch: 'master', target_project: project)
    end

    let!(:merge_request_2) do
      create(:merge_request, :on_train,
        train_creator: maintainer_2,
        source_branch: 'signed-commits', source_project: project,
        target_branch: 'master', target_project: project)
    end

    let(:refresh_service_1) { double }
    let(:refresh_service_2) { double }
    let(:refresh_service_1_result) { { status: :success } }
    let(:refresh_service_2_result) { { status: :success } }

    before do
      allow(MergeTrains::RefreshMergeRequestService)
        .to receive(:new).with(project, maintainer_1, anything) { refresh_service_1 }
      allow(MergeTrains::RefreshMergeRequestService)
        .to receive(:new).with(project, maintainer_2, anything) { refresh_service_2 }

      allow(refresh_service_1).to receive(:execute) { refresh_service_1_result }
      allow(refresh_service_2).to receive(:execute) { refresh_service_2_result }
    end

    context 'when merge request 1 is passed' do
      let(:merge_request) { merge_request_1 }

      it 'executes RefreshMergeRequestService to all the following merge requests' do
        expect(refresh_service_1).to receive(:execute).with(merge_request_1)
        expect(refresh_service_2).to receive(:execute).with(merge_request_2)

        subject
      end

      context 'when refresh service 1 returns error status' do
        let(:refresh_service_1_result) { { status: :error, message: 'Failed to create ref' } }

        it 'specifies require_recreate to refresh service 2' do
          expect(MergeTrains::RefreshMergeRequestService)
            .to receive(:new).with(project, maintainer_2, require_recreate: true) { refresh_service_2 }

          subject
        end
      end

      context 'when refresh service 1 returns success status and did not create a pipeline' do
        let(:refresh_service_1_result) { { status: :success, pipeline_created: false } }

        it 'does not specify require_recreate to refresh service 2' do
          expect(MergeTrains::RefreshMergeRequestService)
            .to receive(:new).with(project, maintainer_2, require_recreate: false) { refresh_service_2 }

          subject
        end
      end

      context 'when refresh service 1 returns success status and created a pipeline' do
        let(:refresh_service_1_result) { { status: :success, pipeline_created: true } }

        it 'specifies require_recreate to refresh service 2' do
          expect(MergeTrains::RefreshMergeRequestService)
            .to receive(:new).with(project, maintainer_2, require_recreate: true) { refresh_service_2 }

          subject
        end
      end

      context 'when merge request 1 is not on a merge train' do
        let(:merge_request) { merge_request_1 }
        let!(:merge_request_1) { create(:merge_request) }

        it 'does not refresh' do
          expect(refresh_service_1).not_to receive(:execute).with(merge_request_1)

          subject
        end
      end

      context 'when merge request 1 was on a merge train' do
        before do
          allow(merge_request_1.merge_train_car).to receive(:cleanup_ref)
          merge_request_1.merge_train_car.update_column(
            :status,
            MergeTrains::Car.state_machines[:status].states[:merged].value
          )
        end

        it 'does not refresh' do
          expect(refresh_service_1).not_to receive(:execute).with(merge_request_1)

          subject
        end
      end
    end

    context 'when merge request 2 is passed' do
      let(:merge_request) { merge_request_2 }

      it 'executes RefreshMergeRequestService to all the merge requests from beginning' do
        expect(refresh_service_1).to receive(:execute).with(merge_request_1)
        expect(refresh_service_2).to receive(:execute).with(merge_request_2)

        subject
      end
    end

    context 'when the exclusive lease is already taken' do
      let(:merge_request) { merge_request_1 }

      before do
        stub_exclusive_lease_taken(service.send(:lease_key), timeout: described_class::LEASE_TIMEOUT)
      end

      it 'does not execute any refresh' do
        expect(refresh_service_1).not_to receive(:execute)
        expect(refresh_service_2).not_to receive(:execute)

        subject
      end
    end

    context 'when the lease cannot be renewed' do
      let(:merge_request) { merge_request_1 }

      it 'stops processing cars' do
        expect(service).to receive(:renew_lease!).and_return(false)

        expect(refresh_service_1).not_to receive(:execute)
        expect(refresh_service_2).not_to receive(:execute)

        subject
      end
    end

    context 'when the lease is renewed successfully' do
      let(:merge_request) { merge_request_1 }

      it 'processes all cars' do
        allow(service).to receive(:renew_lease!).and_return(true)

        expect(refresh_service_1).to receive(:execute).with(merge_request_1)
        expect(refresh_service_2).to receive(:execute).with(merge_request_2)

        subject
      end
    end

    context 'with configurable concurrency limit' do
      let(:merge_request) { merge_request_1 }

      context 'when plan limit is set' do
        before do
          project.actual_limits.update!(max_pipelines_per_merge_train: 5)
        end

        it 'uses the plan limit for concurrency' do
          train = instance_double(MergeTrains::Train)
          allow(MergeTrains::Train).to receive(:new).and_return(train)
          expect(train).to receive(:refreshable_cars).with(limit: 5).and_return([])

          subject
        end
      end

      context 'when project limit is set and lower than plan limit' do
        before do
          project.actual_limits.update!(max_pipelines_per_merge_train: 20)
          project.ci_cd_settings.update!(max_pipelines_per_merge_train: 3)
        end

        it 'uses the project limit as it is lower' do
          train = instance_double(MergeTrains::Train)
          allow(MergeTrains::Train).to receive(:new).and_return(train)
          expect(train).to receive(:refreshable_cars).with(limit: 3).and_return([])

          subject
        end
      end

      context 'when project limit is set but higher than plan limit' do
        before do
          project.actual_limits.update!(max_pipelines_per_merge_train: 10)
          project.ci_cd_settings.update!(max_pipelines_per_merge_train: 15)
        end

        it 'uses the plan limit as it is lower' do
          train = instance_double(MergeTrains::Train)
          allow(MergeTrains::Train).to receive(:new).and_return(train)
          expect(train).to receive(:refreshable_cars).with(limit: 10).and_return([])

          subject
        end
      end

      context 'when project limit is not set' do
        before do
          project.actual_limits.update!(max_pipelines_per_merge_train: 8)
          project.ci_cd_settings.update!(max_pipelines_per_merge_train: nil)
        end

        it 'uses the plan limit' do
          train = instance_double(MergeTrains::Train)
          allow(MergeTrains::Train).to receive(:new).and_return(train)
          expect(train).to receive(:refreshable_cars).with(limit: 8).and_return([])

          subject
        end
      end

      context 'when no custom limits are set' do
        it 'uses the default concurrency of 20' do
          train = instance_double(MergeTrains::Train)
          allow(MergeTrains::Train).to receive(:new).and_return(train)
          expect(train).to receive(:refreshable_cars).with(limit: 20).and_return([])

          subject
        end
      end

      context 'when project is not found' do
        let(:service) { described_class.new(non_existing_record_id, 'main') }

        it 'falls back to default concurrency' do
          train = instance_double(MergeTrains::Train)
          allow(MergeTrains::Train).to receive(:new).and_return(train)
          expect(train).to receive(:refreshable_cars).with(limit: 20).and_return([])

          service.execute
        end
      end

      context 'when using refreshable_cars' do
        let(:merge_request) { merge_request_1 }

        it 'iterates over refreshable cars' do
          expect(MergeTrains::RefreshMergeRequestService)
            .to receive(:new).with(project, maintainer_1, require_recreate: false).and_call_original
          expect(MergeTrains::RefreshMergeRequestService)
            .to receive(:new).with(project, maintainer_2, require_recreate: anything).and_call_original

          subject
        end
      end
    end
  end
end
