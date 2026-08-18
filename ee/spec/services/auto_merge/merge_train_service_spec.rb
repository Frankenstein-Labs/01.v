# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AutoMerge::MergeTrainService, feature_category: :merge_trains do
  include ExclusiveLeaseHelpers

  let_it_be(:project) { create(:project, :repository, merge_pipelines_enabled: true, merge_trains_enabled: true) }
  let_it_be(:user) { create(:user) }

  let(:service) { described_class.new(project, user, params) }
  let(:params) { {} }

  let(:merge_request) do
    create(:merge_request, :with_merge_request_pipeline,
      source_project: project, target_project: project)
  end

  before_all do
    project.add_maintainer(user)
  end

  before do
    allow(AutoMergeProcessWorker).to receive(:perform_async).and_return(nil)

    stub_licensed_features(merge_trains: true, merge_pipelines: true)
  end

  describe '#execute' do
    subject(:service_execute) { service.execute(merge_request) }

    it 'enables auto merge on the merge request' do
      service_execute

      merge_request.reload
      expect(merge_request.auto_merge_enabled).to be_truthy
      expect(merge_request.merge_user).to eq(user)
      expect(merge_request.auto_merge_strategy).to eq(AutoMergeService::STRATEGY_MERGE_TRAIN)
    end

    it 'creates merge train' do
      service_execute

      merge_request.reload
      expect(merge_request.merge_train_car).to be_present
      expect(merge_request.merge_train_car.user).to eq(user)
    end

    it 'creates system note' do
      expect(SystemNoteService)
        .to receive(:merge_train).with(merge_request, project, user, MergeTrains::Car)

      service_execute
    end

    it 'returns result code' do
      is_expected.to eq(:merge_train)
    end

    context 'when merge request is already on the train' do
      before do
        service.execute(merge_request)
      end

      it 'does not change the merge train car' do
        expect { service.execute(merge_request) }.not_to change { merge_request.reload.merge_train_car }
      end
    end

    context 'when failed to save the record' do
      before do
        allow(merge_request).to receive(:save!) { raise PG::QueryCanceled }
      end

      it 'returns result code' do
        is_expected.to eq(:failed)
      end
    end

    context 'when statement timeout happened on system note creation' do
      before do
        allow(SystemNoteService).to receive(:merge_train) { raise PG::QueryCanceled }
      end

      it 'returns failed status' do
        is_expected.to eq(:failed)
      end

      it 'rollback the transaction' do
        expect { service_execute }.not_to change { Note.count }

        merge_request.reload
        expect(merge_request).not_to be_auto_merge_enabled
        expect(merge_request.merge_train_car).not_to be_present
      end

      it 'tracks the exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          kind_of(PG::QueryCanceled),
          merge_request_id: merge_request.id
        )

        service_execute
      end
    end
  end

  describe '#process' do
    subject(:service_process) { service.process(merge_request) }

    let(:merge_request) do
      create(:merge_request, :on_train,
        source_project: project, source_branch: 'feature',
        target_project: project, target_branch: 'master')
    end

    it 'calls RefreshWorker' do
      expect(MergeTrains::RefreshWorker)
        .to receive(:perform_async)
        .with(merge_request.target_project_id, merge_request.target_branch)
        .once

      service_process
    end

    context 'when merge request is not on a merge train' do
      let(:merge_request) { create(:merge_request) }

      it 'does not call RefreshWorker' do
        expect(MergeTrains::RefreshWorker).not_to receive(:perform_async)

        service_process
      end
    end
  end

  describe '#cancel' do
    subject(:service_cancel) { service.cancel(merge_request, **params) }

    let(:params) { {} }

    let!(:merge_request) do
      create(:merge_request, :on_train,
        source_project: project, source_branch: 'feature',
        target_project: project, target_branch: 'master',
        merge_params: {
          'should_remove_source_branch' => true,
          'commit_message' => 'Merge branch xyz into abc',
          'squash_commit_message' => 'Squashed some commits',
          'auto_merge_strategy' => 'merge_train',
          'train_ref' => { 'commit_sha' => 'abc', 'merge_commit_sha' => 'abc' }
        })
    end

    context 'when merge_train_car is nil' do
      before do
        allow(merge_request).to receive(:merge_train_car).and_return(nil)
      end

      it 'does not raise an error' do
        expect { service.cancel(merge_request) }.not_to raise_error
      end
    end

    it 'cancels auto merge on the merge request' do
      service_cancel

      merge_request.reload
      expect(merge_request).not_to be_auto_merge_enabled
      expect(merge_request.merge_user).to be_nil
      expect(merge_request.merge_params).not_to include('should_remove_source_branch')
      expect(merge_request.merge_params).not_to include('commit_message')
      expect(merge_request.merge_params).not_to include('squash_commit_message')
      expect(merge_request.merge_params).not_to include('auto_merge_strategy')
      expect(merge_request.merge_params).not_to include('train_ref')
      expect(merge_request.merge_train_car).not_to be_present
    end

    it 'writes system note to the merge request' do
      expect(SystemNoteService)
        .to receive(:cancel_merge_train).with(merge_request, project, user)

      service_cancel
    end

    it 'does not generate any todos' do
      expect { service_cancel }.not_to change { user.reload.todos.count }
    end

    context 'when pipeline exists' do
      before do
        merge_request.merge_train_car.update!(pipeline: pipeline)
      end

      let(:pipeline) { create(:ci_pipeline) }
      let(:job) { create(:ci_build, :running, pipeline: pipeline) }

      it 'sets the job to a canceled status' do
        expect { service_cancel }.to change { job.reload.status }.from('running').to('canceled')
      end

      context 'when canceling is supported' do
        include_context 'when canceling support'

        it 'sets the job to a canceling status' do
          expect { service_cancel }.to change { job.reload.status }.from('running').to('canceling')
        end
      end
    end

    context 'when train ref exists' do
      before do
        merge_request.project.repository.create_ref(merge_request.target_branch, merge_request.train_ref_path)
      end

      it 'deletes train ref' do
        expect { service_cancel }
          .to change { merge_request.project.repository.ref_exists?(merge_request.train_ref_path) }
          .from(true).to(false)
      end
    end

    context 'when train ref does not exist' do
      it 'does not raise an error' do
        expect { service_cancel }.not_to raise_error
      end
    end

    context 'when the other merge request is following the merge request' do
      let!(:merge_request_2) do
        create(:merge_request, :on_train,
          source_project: project, source_branch: 'signed-commits',
          target_project: project, target_branch: 'master',
          status: status)
      end

      let(:status) { MergeTrains::Car.state_machines[:status].states[:fresh].value }

      it 'processes the train by default' do
        expect(MergeTrains::RefreshWorker).to receive(:perform_async).with(merge_request_2.target_project_id,
          merge_request_2.target_branch)

        service_cancel

        expect(merge_request_2.reset.merge_train_car).to be_stale
      end

      context 'when the status is stale already' do
        let(:status) { MergeTrains::Car.state_machines[:status].states[:stale].value }

        it 'does not do anything' do
          expect(MergeTrains::RefreshWorker).not_to receive(:perform_async)

          expect { service_cancel }.not_to raise_error

          expect(merge_request_2.reset.merge_train_car).to be_stale
        end
      end
    end

    context 'when statement timeout happened on system note creation' do
      before do
        allow(SystemNoteService).to receive(:cancel_merge_train) { raise PG::QueryCanceled }
      end

      it 'returns error' do
        expect(service_cancel[:status]).to eq(:error)
        expect(service_cancel[:message]).to eq("Can't cancel the automatic merge")
      end

      it 'rollback the transaction' do
        expect { service_cancel }.not_to change { Note.count }

        merge_request.reload
        expect(merge_request).to be_auto_merge_enabled
        expect(merge_request.merge_train_car).to be_present
      end

      it 'tracks the exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          kind_of(PG::QueryCanceled),
          merge_request_id: merge_request.id
        )

        service_cancel
      end
    end
  end

  describe '#abort' do
    subject(:service_abort) { service.abort(merge_request, 'an error', **args) }

    let!(:merge_request) do
      create(:merge_request, :on_train,
        source_project: project, source_branch: 'feature',
        target_project: project, target_branch: 'master',
        merge_params: {
          'should_remove_source_branch' => true,
          'commit_message' => 'Merge branch xyz into abc',
          'squash_commit_message' => 'Squashed some commits',
          'auto_merge_strategy' => 'merge_train',
          'train_ref' => { 'commit_sha' => 'abc', 'merge_commit_sha' => 'abc' }
        })
    end

    let(:args) { {} }

    context 'when merge_train_car is nil' do
      before do
        allow(merge_request).to receive(:merge_train_car).and_return(nil)
      end

      it 'does not raise an error' do
        expect { service.abort(merge_request, 'test reason') }.not_to raise_error
      end
    end

    it 'aborts auto merge on the merge request' do
      service_abort

      merge_request.reload
      expect(merge_request).not_to be_auto_merge_enabled
      expect(merge_request.merge_user).to be_nil
      expect(merge_request.merge_params).not_to include('should_remove_source_branch')
      expect(merge_request.merge_params).not_to include('commit_message')
      expect(merge_request.merge_params).not_to include('squash_commit_message')
      expect(merge_request.merge_params).not_to include('auto_merge_strategy')
      expect(merge_request.merge_params).not_to include('train_ref')
      expect(merge_request.merge_train_car).not_to be_present
    end

    it 'writes system note to the merge request' do
      expect(SystemNoteService)
        .to receive(:abort_merge_train).with(merge_request, project, user, 'an error')

      service_abort
    end

    context 'when the merge request is broken (e.g. its fork relationship is gone)' do
      before do
        merge_request.source_project = create(:project)
        allow(merge_request).to receive(:source_project_missing?).and_return(true)
      end

      it 'still aborts auto-merge and removes the merge train car', :aggregate_failures do
        service_abort

        merge_request.reload
        expect(merge_request).not_to be_auto_merge_enabled
        expect(merge_request.merge_train_car).not_to be_present
      end
    end

    it 'updates the merge request train position indicator' do
      expect(GraphqlTriggers)
        .to receive(:merge_request_merge_status_updated).with(merge_request)

      service_abort
    end

    it 'generates new todos', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/324122' do
      todos = merge_request.author.reload.todos
      expect { service_abort }.to change { todos.count }

      expect(todos.last.action).to eq(Todo::MERGE_TRAIN_REMOVED)
      expect(todos.last.state).to eq("pending")
    end

    context 'when the other merge request is following the merge request' do
      let!(:merge_request_2) do
        create(:merge_request, :on_train,
          source_project: project, source_branch: 'signed-commits',
          target_project: project, target_branch: 'master',
          status: MergeTrains::Car.state_machines[:status].states[:fresh].value)
      end

      it 'processes the train' do
        expect(MergeTrains::RefreshWorker).to receive(:perform_async).with(merge_request_2.target_project_id,
          merge_request_2.target_branch)

        service_abort

        expect(merge_request_2.reset.merge_train_car).to be_stale
      end

      context 'when process_next is false' do
        let(:args) { { process_next: false } }

        it 'does not process the next merge request on the train' do
          expect(MergeTrains::RefreshWorker).not_to receive(:perform_async)

          service_abort
        end
      end
    end

    context 'when statement timeout happened on system note creation' do
      before do
        allow(SystemNoteService).to receive(:abort_merge_train) { raise PG::QueryCanceled }
      end

      it 'returns error' do
        expect(service_abort[:status]).to eq(:error)
        expect(service_abort[:message]).to eq("Can't abort the automatic merge")
      end

      it 'rollback the transaction' do
        expect { service_abort }.not_to change { Note.count }

        merge_request.reload
        expect(merge_request).to be_auto_merge_enabled
        expect(merge_request.merge_train_car).to be_present
      end

      it 'tracks the exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          kind_of(PG::QueryCanceled),
          merge_request_id: merge_request.id
        )

        service_abort
      end
    end
  end

  describe '#available_for?' do
    subject { service.available_for?(merge_request) }

    let(:pipeline) do
      instance_double(Ci::Pipeline, complete?: true, active?: false, created?: false, success?: true,
        merge_train_pipeline?: true)
    end

    before do
      allow(merge_request).to receive_messages(mergeable_state?: true, for_fork?: false)
      allow(merge_request).to receive(:diff_head_pipeline) { pipeline }
    end

    it { is_expected.to be_truthy }

    it 'memoizes the result' do
      expect(service).to receive(:available_for?).once.and_call_original

      2.times { is_expected.to be_truthy }
    end

    context 'when merge trains are disabled' do
      before do
        allow(project).to receive(:merge_trains_enabled?).and_return false
      end

      it { is_expected.to be false }
    end

    context 'when project is not licensed for merge trains' do
      before do
        stub_licensed_features(merge_trains: false)
      end

      it { is_expected.to be false }
    end

    context 'when there is an open MR dependency' do
      before do
        stub_licensed_features(blocking_merge_requests: true)
        create(:merge_request_block, blocked_merge_request: merge_request)
      end

      it { is_expected.to be false }
    end

    context 'when merge request is not mergeable' do
      let(:failed_result) do
        Gitlab::MergeRequests::Mergeability::CheckResult.failed(payload: { identifier: 'failed_check' })
      end

      before do
        allow_next_instance_of(MergeRequests::Mergeability::CheckOpenStatusService) do |service|
          allow(service).to receive_messages(skip?: false, execute: failed_result)
        end
      end

      it { is_expected.to be false }
    end

    context 'when the user does not have permission to merge' do
      before do
        allow(merge_request).to receive(:can_be_merged_by?).and_return(false)
      end

      it { is_expected.to be false }
    end

    context 'when the head pipeline of the merge request has not finished and is not blocked' do
      before do
        allow(pipeline).to receive_messages(complete?: false, active?: true, blocked?: false, canceling?: false,
          success?: false)
      end

      it { is_expected.to be false }
    end

    context 'when the head pipeline of the pipeline is blocked' do
      before do
        allow(pipeline).to receive_messages(active?: false, created?: false, complete?: false, blocked?: true,
          canceling?: false, success?: false)
      end

      it { is_expected.to be true }

      context 'when "Pipelines must succeed" is enabled' do
        before do
          allow(merge_request).to receive(:only_allow_merge_if_pipeline_succeeds?).and_return(true)
        end

        it { is_expected.to be false }
      end
    end

    context 'when the head pipeline of the pipeline is canceling' do
      before do
        allow(pipeline).to receive_messages(active?: false, created?: false, complete?: false, blocked?: false,
          canceling?: true)
      end

      it { is_expected.to be true }

      context 'when "Pipelines must succeed" is enabled' do
        before do
          allow(merge_request).to receive(:only_allow_merge_if_pipeline_succeeds?).and_return(true)
        end

        it { is_expected.to be false }
      end
    end
  end

  describe '#skippable_available_for_checks' do
    subject(:skippable_checks) { service.send(:skippable_available_for_checks, merge_request) }

    context 'when auto merge strategy is STRATEGY_MERGE_TRAIN' do
      it 'includes skip_rebase_check' do
        expect(skippable_checks).to include(skip_rebase_check: true)
      end

      it 'does not skip conflict check' do
        expect(skippable_checks).to include(skip_conflict_check: false)
      end
    end

    context 'when auto merge strategy is STRATEGY_ADD_TO_MERGE_TRAIN_WHEN_CHECKS_PASS' do
      let(:params) { { auto_merge_strategy: AutoMergeService::STRATEGY_ADD_TO_MERGE_TRAIN_WHEN_CHECKS_PASS } }
      let(:service) { described_class.new(project, user, params) }

      before do
        merge_request.update!(auto_merge_enabled: true, merge_user: user)
        merge_request.merge_params['auto_merge_strategy'] =
          AutoMergeService::STRATEGY_ADD_TO_MERGE_TRAIN_WHEN_CHECKS_PASS
      end

      it 'includes skip_rebase_check' do
        expect(skippable_checks).to include(skip_rebase_check: true)
      end

      it 'skips conflict check' do
        expect(skippable_checks).to include(skip_conflict_check: true)
      end
    end
  end

  describe '#availability_details' do
    subject(:availability_check) { service.availability_details(merge_request) }

    let(:pipeline) do
      instance_double(Ci::Pipeline, complete?: true, active?: false, created?: false, success?: true,
        merge_train_pipeline?: true)
    end

    before do
      allow(merge_request).to receive_messages(mergeable_state?: true, for_fork?: false)
      allow(merge_request).to receive(:diff_head_pipeline) { pipeline }
    end

    it 'is available and has no unavailable reason' do
      aggregate_failures do
        expect(availability_check.available?).to be true
        expect(availability_check.unavailable_reason).to be_nil
      end
    end

    it 'memoizes the result' do
      expect(service).to receive(:availability_details).once.and_call_original

      2.times { is_expected.to be_truthy }
    end

    context 'when merge trains are disabled' do
      before do
        allow(project).to receive(:merge_trains_enabled?).and_return false
      end

      it 'is unavailable and returns the correct reason' do
        aggregate_failures do
          expect(availability_check.available?).to be false
          expect(availability_check.unavailable_reason).to eq :merge_trains_disabled
        end
      end
    end

    context 'when there is an open MR dependency' do
      before do
        stub_licensed_features(blocking_merge_requests: true)
        create(:merge_request_block, blocked_merge_request: merge_request)
      end

      it 'is unavailable and returns the correct reason' do
        aggregate_failures do
          expect(availability_check.available?).to be false
          expect(availability_check.unavailable_reason).to eq :mergeability_checks_failed
        end
      end
    end

    context 'when mergeability checks fail' do
      let(:identifier) { 'failed_check' }
      let(:failed_result) do
        Gitlab::MergeRequests::Mergeability::CheckResult.failed(payload: { identifier: identifier })
      end

      before do
        allow_next_instance_of(MergeRequests::Mergeability::CheckOpenStatusService) do |service|
          allow(service).to receive_messages(skip?: false, execute: failed_result)
        end
      end

      it 'is unavailable and returns the correct reason' do
        aggregate_failures do
          expect(availability_check.available?).to be false
          expect(availability_check.unavailable_reason).to eq :mergeability_checks_failed
          expect(availability_check.unsuccessful_check).to eq identifier.to_sym
        end
      end
    end

    context 'when the user does not have permission to merge' do
      before do
        allow(merge_request).to receive(:can_be_merged_by?).and_return(false)
      end

      it 'is unavailable and returns the correct reason' do
        aggregate_failures do
          expect(availability_check.available?).to be false
          expect(availability_check.unavailable_reason).to eq :forbidden
        end
      end
    end

    context 'when the head pipeline of the merge request has not finished and is not blocked' do
      before do
        allow(pipeline).to receive_messages(complete?: false, active?: true, blocked?: false, canceling?: false,
          success?: false)
      end

      it 'is unavailable and returns the correct reason' do
        aggregate_failures do
          expect(availability_check.available?).to be false
          expect(availability_check.unavailable_reason).to eq :incomplete_diff_head_pipeline
        end
      end
    end

    context 'when the head pipeline of the pipeline is blocked' do
      before do
        allow(pipeline).to receive_messages(active?: false, created?: false, complete?: false, blocked?: true,
          canceling?: false, success?: false)
      end

      it 'is available and has no unavailable reason' do
        aggregate_failures do
          expect(availability_check.available?).to be true
          expect(availability_check.unavailable_reason).to be_nil
        end
      end

      context 'when "Pipelines must succeed" is enabled' do
        before do
          allow(merge_request).to receive(:only_allow_merge_if_pipeline_succeeds?).and_return(true)
        end

        it 'is unavailable and returns the correct reason' do
          aggregate_failures do
            expect(availability_check.available?).to be false
            expect(availability_check.unavailable_reason).to eq :incomplete_diff_head_pipeline
          end
        end
      end
    end

    context 'when the head pipeline of the pipeline is canceling' do
      before do
        allow(pipeline).to receive_messages(active?: false, created?: false, complete?: false, blocked?: false,
          canceling?: true, success?: false)
      end

      it 'is available and has no unavailable reason' do
        aggregate_failures do
          expect(availability_check.available?).to be true
          expect(availability_check.unavailable_reason).to be_nil
        end
      end

      context 'when "Pipelines must succeed" is enabled' do
        before do
          allow(merge_request).to receive(:only_allow_merge_if_pipeline_succeeds?).and_return(true)
        end

        it 'is unavailable and returns the correct reason' do
          aggregate_failures do
            expect(availability_check.available?).to be false
            expect(availability_check.unavailable_reason).to eq :incomplete_diff_head_pipeline
          end
        end
      end
    end
  end
end

def create_pipeline_for(merge_request)
  MergeRequests::CreatePipelineService.new(project: project, current_user: user).execute(merge_request)
end
