# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeTrains::RefreshMergeRequestService, feature_category: :source_code_management do
  let(:project) { create(:project, :repository, merge_pipelines_enabled: true, merge_trains_enabled: true) }
  let_it_be(:maintainer) { create(:user) }

  let(:service) { described_class.new(project, maintainer, require_recreate: require_recreate) }
  let(:require_recreate) { false }
  let(:expected_create_mergeable_ref) { true }

  before do
    project.add_maintainer(maintainer)
    stub_licensed_features(merge_pipelines: true, merge_trains: true)
    project.update!(merge_pipelines_enabled: true, merge_trains_enabled: true) unless project.merge_pipelines_enabled == true && project.merge_trains_enabled == true
  end

  describe '#execute' do
    subject { service.execute(merge_request) }

    let!(:merge_request) do
      create(:merge_request, :on_train,
        train_creator: maintainer,
        source_branch: 'feature', source_project: project,
        target_branch: 'master', target_project: project)
    end

    shared_examples_for 'drops the merge request from the merge train' do
      let(:expected_reason) { 'unknown' }

      specify do
        expect_next_instance_of(AutoMerge::MergeTrainService) do |service|
          expect(service).to receive(:abort).with(merge_request, expected_reason, hash_including(process_next: false))
        end

        subject
      end
    end

    shared_examples_for 'creates a pipeline for merge train' do
      let(:previous_ref) { 'refs/heads/master' }

      specify do
        expect_next_instance_of(MergeTrains::CreatePipelineService, project, maintainer) do |pipeline_service|
          allow(pipeline_service).to receive(:execute) { { status: :success, pipeline: pipeline } }
          expect(pipeline_service).to receive(:execute).with(merge_request, previous_ref, expected_create_mergeable_ref)
        end

        result = subject
        expect(result[:status]).to eq(:success)
        expect(result[:pipeline_created]).to be(true)
        expect(merge_request.merge_train_car).to be_fresh
      end
    end

    shared_examples_for 'cancels and recreates a pipeline for the merge train' do
      let(:previous_ref) { 'refs/heads/master' }

      it 'cancels and recreates a pipeline for the merge train', :sidekiq_might_not_need_inline do
        expect_next_instance_of(MergeTrains::CreatePipelineService, project, maintainer) do |pipeline_service|
          allow(pipeline_service).to receive(:execute) { { status: :success, pipeline: create(:ci_pipeline) } }
          expect(pipeline_service).to receive(:execute).with(merge_request, previous_ref, expected_create_mergeable_ref)
        end

        result = subject
        new_pipeline = merge_request.merge_train_car.pipeline
        pipeline.reset

        expect(result[:status]).to eq(:success)
        expect(result[:pipeline_created]).to be(true)
        expect(pipeline.status).to eq('canceled')
        expect(pipeline.auto_canceled_by_id).to eq(new_pipeline.id)
      end
    end

    shared_examples_for 'does not create a pipeline' do
      specify do
        expect(service).not_to receive(:create_pipeline!)

        result = subject
        expect(result[:status]).to eq(:success)
        expect(result[:pipeline_created]).to be_falsy
      end
    end

    shared_examples_for 'merges the merge request' do
      specify do
        expect(merge_request).to receive(:schedule_cleanup_refs).with(only: :train)
        expect(merge_request.merge_train_car).to receive(:start_merge!).and_call_original
        expect(merge_request.merge_train_car).to receive(:finish_merge!).and_call_original
        expect_next_instance_of(MergeRequests::MergeService, project: project, current_user: maintainer, params: instance_of(HashWithIndifferentAccess)) do |service|
          expect(service).to receive(:execute).with(merge_request, skip_discussions_check: true, check_mergeability_retry_lease: true).and_call_original
        end

        expect { subject }.to change { merge_request.merge_train_car.status_name }.from(:fresh).to(:merged)
        expect(merge_request.state).to eq("merged")
      end
    end

    context 'when the merge request is locked but already merged in the repository' do
      let(:pipeline) { create(:ci_pipeline, :success, project: project) }

      before do
        allow(merge_request).to receive_messages(
          locked?: true,
          merged?: false,
          merged_in_repository?: true
        )

        merge_request.merge_train_car.update!(
          status: MergeTrains::Car.state_machines[:status].states[:merging].value,
          pipeline: pipeline,
          updated_at: 3.hours.ago
        )
        merge_request.update!(
          state_id: MergeRequest.available_states[:locked],
          in_progress_merge_commit_sha: 'abc123',
          updated_at: 3.hours.ago
        )
      end

      it 'reconciles the state to merged and finishes the train car' do
        expect(merge_request).to receive(:mark_as_merged!).and_call_original
        expect(merge_request.merge_train_car).to receive(:finish_merge!).and_call_original

        expect(Gitlab::AppLogger).to receive(:warn).with(
          hash_including(
            message: 'Unstuck stuck merge train merge',
            action: 'reconciled_silently_merged'
          )
        )
        subject
        expect(merge_request.state).to eq('merged')
      end

      it 'does not call handle_locked_stuck_car (no force-unlock attempt)' do
        allow(merge_request).to receive(:mark_as_merged!).and_return(true)
        allow(merge_request.merge_train_car).to receive(:finish_merge!).and_return(true)

        expect(merge_request).not_to receive(:unlock_mr)

        subject
      end
    end

    context 'when mark_as_merged! raises InvalidTransition' do
      let(:pipeline) { create(:ci_pipeline, :success, project: project) }

      before do
        allow(merge_request).to receive(:mark_as_merged!)
          .and_raise(StateMachines::InvalidTransition.new(merge_request, MergeRequest.state_machines[:state_id], :mark_as_merged))
        allow(merge_request).to receive(:unlock_mr).and_return(true)
        merge_request.merge_train_car.update!(
          status: MergeTrains::Car.state_machines[:status].states[:merging].value,
          pipeline: pipeline,
          updated_at: 3.hours.ago
        )
        merge_request.update!(
          state_id: MergeRequest.available_states[:locked],
          in_progress_merge_commit_sha: 'abc123',
          updated_at: 3.hours.ago
        )
        allow(merge_request).to receive_messages(
          locked?: true,
          merged?: false,
          merged_in_repository?: true
        )
      end

      it 'tracks the exception and falls back to handle_locked_stuck_car' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(StateMachines::InvalidTransition),
          hash_including(handler: 'handle_silently_merged_stuck_car')
        )

        expect(merge_request).to receive(:unlock_mr)

        subject
      end
    end

    context 'when the merge request is locked and NOT merged in the repository' do
      let(:pipeline) { create(:ci_pipeline, :success, project: project) }

      before do
        merge_request.merge_train_car.update!(
          status: MergeTrains::Car.state_machines[:status].states[:merging].value,
          pipeline: pipeline,
          updated_at: 3.hours.ago
        )
        merge_request.update!(
          state_id: MergeRequest.available_states[:locked],
          in_progress_merge_commit_sha: 'abc123',
          updated_at: 3.hours.ago
        )
        allow(merge_request).to receive_messages(
          locked?: true,
          merged?: false,
          merged_in_repository?: false
        )
      end

      it 'falls through to handle_locked_stuck_car' do
        expect(merge_request).to receive(:unlock_mr).and_return(true)

        expect(Gitlab::AppLogger).to receive(:warn).with(
          hash_including(action: 'abort_merge_locked')
        )
        subject
      end
    end

    context 'when the merge request is open and not locked but stuck' do
      before do
        merge_request.merge_train_car.update_columns(
          status: MergeTrains::Car.state_machines[:status].states[:merging].value,
          updated_at: 3.hours.ago
        )
        merge_request.unlock_mr
        merge_request.update_columns(updated_at: 3.hours.ago)
      end

      it 'aborts without calling unlock_mr' do
        expect(merge_request).not_to receive(:unlock_mr)

        expect_next_instance_of(AutoMerge::MergeTrainService) do |svc|
          expect(svc).to receive(:abort).with(
            merge_request,
            a_string_matching(/train car got stuck in merging/),
            hash_including(process_next: false)
          )
        end

        subject
      end
    end

    context 'when an unexpected error occurs during execution' do
      let(:unexpected_error) { StandardError.new("boom") }

      before do
        allow(merge_request.merge_train_car).to receive_messages(
          requires_new_pipeline?: false,
          merge_ready_pipeline?: true
        )

        allow(service).to receive_messages(
          require_recreate?: false,
          create_pipeline!: nil
        )

        allow(service).to receive(:merge!).and_raise(unexpected_error)
      end

      it 'tracks the error and aborts with a ProcessError' do
        expect(Gitlab::ErrorTracking)
          .to receive(:track_exception)
          .with(
            unexpected_error,
            merge_request_id: merge_request.id,
            merge_request_iid: merge_request.iid,
            project_id: merge_request.target_project_id
          )

        expect(service).to receive(:abort) do |error|
          expect(error).to be_a(described_class::ProcessError)
          expect(error.message).to eq(
            "unexpected error occurred - correlation id: #{Labkit::Correlation::CorrelationId.current_or_new_id}"
          )
        end

        subject
      end
    end

    context 'when merge pipelines project configuration is disabled' do
      before do
        project.update!(merge_pipelines_enabled: false)
      end

      it_behaves_like 'drops the merge request from the merge train' do
        let(:expected_reason) { 'project disabled merge trains' }
      end
    end

    context 'when merge trains not enabled' do
      before do
        project.update!(merge_trains_enabled: false)
      end

      it_behaves_like 'drops the merge request from the merge train' do
        let(:expected_reason) { 'project disabled merge trains' }
      end
    end

    context 'when merge request is not in a mergeable state' do
      context 'when merge request is a draft' do
        before do
          merge_request.update!(title: merge_request.draft_title)
        end

        it_behaves_like 'drops the merge request from the merge train' do
          let(:expected_reason) do
            'the merge request is marked as draft. ' \
              '[Learn more](http://localhost/help/ci/pipelines/merge_trains.md#merge-request-dropped-from-the-merge-train).'
          end
        end
      end

      context 'when the car is merging but not timed out and has no pipeline' do
        before do
          not_stuck_yet = (MergeTrains::Car::STUCK_AFTER - 5.minutes).ago
          car = merge_request.merge_train_car
          car.update_columns(pipeline_id: nil, updated_at: not_stuck_yet, status: MergeTrains::Car.state_machines[:status].states[:merging].value)
          car.reload
        end

        it 'does not unstick because not timed out' do
          expect(Gitlab::AppLogger).not_to receive(:warn).with(
            hash_including(message: 'Unstuck stuck merge train merge')
          )

          expect { subject }.to raise_error(MergeTrains::RefreshMergeRequestService::ConcurrencyError, /error/)
        end
      end

      context 'when merge request is not open' do
        before do
          allow(merge_request).to receive(:open?).and_return(false)
        end

        it_behaves_like 'drops the merge request from the merge train' do
          let(:expected_reason) do
            'the merge request is closed. ' \
              '[Learn more](http://localhost/help/ci/pipelines/merge_trains.md#merge-request-dropped-from-the-merge-train).'
          end
        end
      end

      context 'when merge request is broken' do
        before do
          allow(merge_request).to receive(:broken?).and_return(true)
        end

        it_behaves_like 'drops the merge request from the merge train' do
          let(:expected_reason) do
            'the merge request is broken. ' \
              '[Learn more](http://localhost/help/ci/pipelines/merge_trains.md#merge-request-dropped-from-the-merge-train).'
          end
        end
      end

      context 'when auto merge is not set' do
        before do
          # simulate clearing the auto merge parameters with a car present
          merge_request.update!(auto_merge_enabled: false, merge_user_id: nil)
        end

        it_behaves_like 'drops the merge request from the merge train' do
          let(:expected_reason) do
            'the merge request is not set to auto-merge'
          end
        end
      end
    end

    context 'when the merge train car is in merging' do
      let(:pipeline) { create(:ci_pipeline, :success, project: project) }

      before do
        merge_request.merge_train_car.update!(
          status: MergeTrains::Car.state_machines[:status].states[:merging].value,
          pipeline: pipeline,
          updated_at: 3.hours.ago
        )
        merge_request.update!(
          state_id: MergeRequest.available_states[:locked],
          in_progress_merge_commit_sha: 'abc123',
          updated_at: 3.hours.ago
        )
      end

      context 'when the merge request is closed and car destroy fails' do
        before do
          merge_request.update!(state_id: MergeRequest.available_states[:closed])
          allow(merge_request.merge_train_car).to receive(:destroy).and_return(false)
        end

        it 'logs the failure and returns success' do
          expect(Gitlab::AppLogger).to receive(:warn).with(
            hash_including(
              message: 'Unstuck stuck merge train merge',
              action: 'destroy_failed'
            )
          )

          result = subject

          expect(result[:status]).to eq(:success)
        end
      end

      context 'when the merge request is open and stuck' do
        before do
          merge_request.unlock_mr
          merge_request.update_columns(updated_at: 3.hours.ago)
        end

        it 'aborts via open stuck car handler' do
          expect(Gitlab::AppLogger).to receive(:warn).with(
            hash_including(
              message: 'Unstuck stuck merge train merge',
              action: 'abort_merge_open'
            )
          )

          expect_next_instance_of(AutoMerge::MergeTrainService) do |svc|
            expect(svc).to receive(:abort).with(
              merge_request,
              a_string_matching(/train car got stuck in merging/),
              hash_including(process_next: false)
            )
          end

          subject
        end
      end

      context 'when the merge request is closed and stuck' do
        before do
          merge_request.update!(state_id: MergeRequest.available_states[:closed])
        end

        it 'silently destroys the car' do
          expect(Gitlab::AppLogger).to receive(:warn).with(
            hash_including(
              message: 'Unstuck stuck merge train merge',
              action: 'destroy_closed'
            )
          )

          result = subject

          expect(result[:status]).to eq(:success)
        end
      end

      context 'when the merge request has actually been merged' do
        before do
          merge_request.update!(state_id: MergeRequest.available_states[:merged])
        end

        it 'finishes the merge and logs the action' do
          expect(Gitlab::AppLogger).to receive(:warn).with(
            hash_including(
              message: 'Unstuck stuck merge train merge',
              action: 'finish_merge'
            )
          )

          result = subject

          expect(result[:status]).to eq(:success)
        end
      end

      context 'when the merge request is in an unexpected state' do
        before do
          # Force an unrecognized state by stubbing all state checks to false
          allow(merge_request).to receive_messages(merged?: false, locked?: false, open?: false, closed?: false)
        end

        it 'tracks the exception and aborts' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            an_instance_of(StandardError),
            hash_including(
              merge_request_id: merge_request.id,
              merge_request_iid: merge_request.iid,
              project_id: merge_request.target_project_id
            )
          )

          expect_next_instance_of(AutoMerge::MergeTrainService) do |svc|
            expect(svc).to receive(:abort).with(
              merge_request,
              a_string_matching(/train car got stuck in merging/),
              hash_including(process_next: false)
            )
          end

          subject
        end
      end

      context 'when the merge request is locked and stuck' do
        it 'unlocks the MR, aborts the merge, and drops from train' do
          expect(Gitlab::AppLogger).to receive(:warn).with(
            hash_including(
              message: 'Unstuck stuck merge train merge',
              action: 'abort_merge_locked'
            )
          )

          expect_next_instance_of(AutoMerge::MergeTrainService) do |service|
            expect(service).to receive(:abort).with(
              merge_request,
              a_string_matching(/train car got stuck in merging/),
              hash_including(process_next: false)
            )
          end

          subject

          merge_request.reload
          expect(merge_request.state).to eq('opened')
        end

        context 'when the car has no pipeline' do
          before do
            merge_request.merge_train_car.update!(pipeline: nil)
          end

          it 'is not considered stuck' do
            expect { subject }.to raise_error(MergeTrains::RefreshMergeRequestService::ConcurrencyError, /error/)
          end
        end
      end

      context 'when the car is merging but not stuck yet' do
        before do
          merge_request.merge_train_car.update!(updated_at: 10.minutes.ago)
          merge_request.update!(updated_at: 10.minutes.ago)
        end

        it 'does not unstick' do
          expect(Gitlab::AppLogger).not_to receive(:warn).with(
            hash_including(message: 'Unstuck stuck merge train merge')
          )

          expect { subject }.to raise_error(MergeTrains::RefreshMergeRequestService::ConcurrencyError, /error/)
        end
      end

      context 'when the car is merging but not timed out' do
        let(:pipeline) { create(:ci_pipeline, :running, project: project) }

        before do
          not_stuck_yet = (MergeTrains::Car::STUCK_AFTER - 5.minutes).ago
          merge_request.merge_train_car.update_columns(updated_at: not_stuck_yet)
          merge_request.update_columns(updated_at: not_stuck_yet)
        end

        it 'does not unstick' do
          expect(Gitlab::AppLogger).not_to receive(:warn).with(
            hash_including(message: 'Unstuck stuck merge train merge')
          )

          expect { subject }.to raise_error(MergeTrains::RefreshMergeRequestService::ConcurrencyError, /error/)
        end
      end

      context 'when the merge request is locked and normal unlock fails due to validation errors' do
        before do
          allow(merge_request).to receive(:unlock_mr).and_return(false, true)
          allow(merge_request).to receive(:add_to_locked_set).and_call_original
        end

        it 'force unlocks, aborts the train car and hands over to another unlock service' do
          expect(Gitlab::AppLogger).to receive(:warn).with(
            hash_including(
              message: 'Unstuck stuck merge train merge',
              action: 'forced_unlock'
            )
          )

          expect_next_instance_of(AutoMerge::MergeTrainService) do |svc|
            expect(svc).to receive(:abort).with(
              merge_request,
              a_string_matching(/train car got stuck in merging/),
              hash_including(process_next: false)
            )
          end

          subject

          expect(merge_request).to have_received(:unlock_mr)
          expect(merge_request).to have_received(:add_to_locked_set)
        end
      end
    end

    context 'when pipeline for merge train failed' do
      let(:pipeline) { create(:ci_pipeline, :failed) }

      before do
        merge_request.merge_train_car.update!(pipeline: pipeline)
      end

      it_behaves_like 'drops the merge request from the merge train' do
        let(:expected_reason) do
          'the pipeline did not succeed. ' \
            '[Learn more](http://localhost/help/ci/pipelines/merge_trains.md#merge-request-dropped-from-the-merge-train).'
        end
      end
    end

    context 'when merge request is to be squashed' do
      before do
        merge_request.update!(squash: true)
      end

      let(:pipeline) { create(:ci_pipeline) }

      it_behaves_like 'creates a pipeline for merge train'
    end

    context 'when previous ref is not found' do
      let(:previous_ref) { 'refs/tmp/test' }

      before do
        allow(merge_request.merge_train_car).to receive(:previous_ref) { previous_ref }
      end

      it_behaves_like 'drops the merge request from the merge train' do
        let(:expected_reason) do
          'the previous ref does not exist. ' \
            '[Learn more](http://localhost/help/ci/pipelines/merge_trains.md#merge-request-dropped-from-the-merge-train).'
        end
      end
    end

    context 'when pipeline has not been created yet' do
      let(:pipeline) { create(:ci_pipeline) }

      context 'when the merge request is the first queue' do
        it_behaves_like 'creates a pipeline for merge train'

        context 'when it failed to create a pipeline' do
          before do
            allow_next_instance_of(MergeTrains::CreatePipelineService) do |instance|
              allow(instance).to receive(:execute).and_return({ result: :error, message: 'failed to create pipeline' })
            end
          end

          it_behaves_like 'drops the merge request from the merge train' do
            let(:expected_reason) { 'failed to create pipeline' }
          end
        end
      end
    end

    context 'when pipeline for merge train is running' do
      let(:pipeline) { create(:ci_pipeline, :running, :with_job, project: project, target_sha: previous_ref_sha, source_sha: merge_request.diff_head_sha) }
      let(:previous_ref_sha) { project.repository.commit('refs/heads/master').sha }

      before do
        merge_request.merge_train_car.refresh_pipeline!(pipeline.id)
      end

      context 'when the pipeline is not stale' do
        it_behaves_like 'does not create a pipeline'
      end

      context 'when the pipeline is stale' do
        before do
          merge_request.merge_train_car.update_column(:status, MergeTrains::Car.state_machines[:status].states[:stale].value)
        end

        it_behaves_like 'cancels and recreates a pipeline for the merge train'
      end

      context 'when the pipeline is required to be recreated' do
        let(:require_recreate) { true }

        it_behaves_like 'cancels and recreates a pipeline for the merge train'
      end

      context 'when discussion is added and project is set to only merge if all discussions resolved' do
        before do
          project.update!(only_allow_merge_if_all_discussions_are_resolved: true)
        end

        it 'continues with the current pipeline' do
          create(:discussion_note_on_merge_request, noteable: merge_request, project: project)

          result = subject

          expect(result[:pipeline_created]).to be(false)
          expect(result[:status]).to eq(:success)
          expect(merge_request.merge_status).to eq("can_be_merged")
          expect(merge_request.merge_params).to eq({ "auto_merge_strategy" => "merge_train" })
        end
      end
    end

    context 'when pipeline for merge train succeeded' do
      let(:previous_ref_sha) { project.repository.commit('refs/heads/master').sha }
      let(:pipeline) { create(:ci_pipeline, :success, target_sha: previous_ref_sha, source_sha: merge_request.diff_head_sha) }

      before do
        merge_request.merge_train_car.refresh_pipeline!(pipeline.id)
        merge_request.merge_params['sha'] = merge_request.diff_head_sha
        merge_request.save!
      end

      context 'when a new discussion is added and project only allow merges when all discussions are resolved' do
        before do
          project.update!(only_allow_merge_if_all_discussions_are_resolved: true)
          create(:discussion_note_on_merge_request, noteable: merge_request, project: project)
        end

        it_behaves_like 'merges the merge request'
      end

      context 'when the merge request is the first queue' do
        let(:policy) { create(:scan_result_policy_read, project: project) }

        it_behaves_like 'merges the merge request'

        context 'when a security scan is running' do
          before do
            create(:scan_result_policy_violation, :running, project: project, merge_request: merge_request,
              scan_result_policy_read: policy, violation_data: nil)
          end

          it 'logs that the scan is running' do
            project.update!(merge_method: :ff)
            project.repository.raw_repository.write_ref(merge_request.train_ref_path, pipeline.sha)
            expect(Gitlab::AppLogger).to receive(:warn).with("Security scans running")

            subject
          end
        end

        context 'when no scan is running' do
          before do
            create(:scan_result_policy_violation, :warn, project: project, merge_request: merge_request,
              scan_result_policy_read: policy, violation_data: nil)
          end

          it 'does not log' do
            project.update!(merge_method: :ff)
            project.repository.raw_repository.write_ref(merge_request.train_ref_path, pipeline.sha)
            expect(Gitlab::AppLogger).not_to receive(:warn)

            subject
          end
        end

        using RSpec::Parameterized::TableSyntax

        where(:merge_method) do
          [:ff, :rebase_merge]
        end

        context 'when merge method is standard merge commit' do
          before do
            project.update!(merge_method: :merge)
          end

          context 'when merge_trains_use_train_ref_for_standard_merges is disabled' do
            before do
              stub_feature_flags(merge_trains_use_train_ref_for_standard_merges: false)
            end

            it 'uses the default merge strategy' do
              expect_next_instance_of(
                MergeRequests::MergeService,
                project: project, current_user: maintainer,
                params: instance_of(HashWithIndifferentAccess)
              ) do |service|
                expect(service).to receive(:execute).with(
                  merge_request,
                  skip_discussions_check: true,
                  check_mergeability_retry_lease: true
                ).and_call_original
              end

              subject
            end
          end

          context 'when merge_trains_use_train_ref_for_standard_merges is enabled' do
            before do
              project.repository.raw_repository.write_ref(
                merge_request.train_ref_path, pipeline.sha
              )
            end

            context 'when skip train is allowed' do
              before do
                stub_feature_flags(merge_trains_skip_train: project)
                project.ci_cd_settings.update!(merge_trains_skip_train_allowed: true)
                merge_request.update!(
                  merge_params: merge_request.merge_params.merge(
                    'train_ref' => { 'commit_sha' => pipeline.sha }
                  )
                )
              end

              it 'uses the default merge strategy' do
                expect_next_instance_of(
                  MergeRequests::MergeService,
                  project: project, current_user: maintainer,
                  params: instance_of(HashWithIndifferentAccess)
                ) do |service|
                  expect(service).to receive(:execute).with(
                    merge_request,
                    skip_discussions_check: true,
                    check_mergeability_retry_lease: true
                  )
                end

                subject
              end
            end

            context 'when it is not safe to merge directly from ref' do
              it 'uses the default merge strategy' do
                expect_next_instance_of(
                  MergeRequests::MergeService,
                  project: project, current_user: maintainer,
                  params: instance_of(HashWithIndifferentAccess)
                ) do |service|
                  expect(service).to receive(:execute).with(
                    merge_request,
                    skip_discussions_check: true,
                    check_mergeability_retry_lease: true
                  )
                end

                subject
              end
            end

            context 'when it is safe to merge directly from ref' do
              before do
                merge_request.update!(
                  merge_params: merge_request.merge_params.merge(
                    'train_ref' => { 'commit_sha' => pipeline.sha }
                  )
                )
              end

              it 'uses the FromTrainRef merge strategy', :aggregate_failures do
                expect(merge_request).to receive(:schedule_cleanup_refs).with(only: :train)
                expect(merge_request.merge_train_car).to receive(:start_merge!).and_call_original
                expect(merge_request.merge_train_car).to receive(:finish_merge!).and_call_original
                expect_next_instance_of(
                  MergeRequests::MergeService,
                  project: project, current_user: maintainer,
                  params: instance_of(HashWithIndifferentAccess)
                ) do |service|
                  expect(service).to receive(:execute).with(
                    merge_request,
                    skip_discussions_check: true,
                    check_mergeability_retry_lease: true,
                    merge_strategy: MergeRequests::MergeStrategies::FromTrainRef
                  ).and_call_original
                end

                expect { subject }.to change {
                  merge_request.merge_train_car.status_name
                }.from(:fresh).to(:merged)
                expect(subject[:status]).to eq(:success)
                expect(merge_request.state).to eq("merged")
              end
            end
          end
        end

        with_them do
          before do
            project.update!(merge_method: merge_method)
            project.repository.raw_repository.write_ref(merge_request.train_ref_path, pipeline.sha)
          end

          context 'when it is not safe to merge directly from ref' do
            it 'uses the default merge strategy' do
              expect_next_instance_of(MergeRequests::MergeService, project: project, current_user: maintainer, params: instance_of(HashWithIndifferentAccess)) do |service|
                expect(service).to receive(:execute).with(merge_request, skip_discussions_check: true, check_mergeability_retry_lease: true)
              end

              subject
            end
          end

          context 'when it is safe to merge directly from ref' do
            before do
              merge_request.update!(
                merge_params: merge_request.merge_params.merge(
                  'train_ref' => {
                    'commit_sha' => pipeline.sha
                  }
                )
              )
            end

            it 'uses the FromTrainRef merge strategy', :aggregate_failures do
              expect(merge_request).to receive(:schedule_cleanup_refs).with(only: :train)
              expect(merge_request.merge_train_car).to receive(:start_merge!).and_call_original
              expect(merge_request.merge_train_car).to receive(:finish_merge!).and_call_original
              expect_next_instance_of(MergeRequests::MergeService, project: project, current_user: maintainer, params: instance_of(HashWithIndifferentAccess)) do |service|
                expect(service).to(
                  receive(:execute).with(
                    merge_request,
                    skip_discussions_check: true,
                    check_mergeability_retry_lease: true,
                    merge_strategy: MergeRequests::MergeStrategies::FromTrainRef
                  ).and_call_original
                )
              end

              expect { subject }.to change { merge_request.merge_train_car.status_name }.from(:fresh).to(:merged)
              expect(subject[:status]).to eq(:success)
              expect(subject[:message]).to be_nil
              expect(merge_request.state).to eq("merged")
            end
          end
        end

        context 'when it failed to merge the merge request' do
          before do
            allow(merge_request).to receive(:broken?).and_return(false)
            merge_request.update!(merge_error: 'Branch has been updated since the merge was requested.')
            allow_next_instance_of(MergeRequests::MergeService) do |instance|
              allow(instance).to receive(:execute).and_return({ result: :error })
            end
          end

          it 'does not finish merge and drops the merge request from train' do
            expect(merge_request).to be_on_train
            expect(merge_request.merge_train_car).to receive(:start_merge!).and_call_original
            expect(merge_request.merge_train_car).not_to receive(:finish_merge!)

            subject

            expect(merge_request.reload).not_to be_on_train
          end

          it_behaves_like 'drops the merge request from the merge train' do
            let(:expected_reason) { 'failed to merge. Branch has been updated since the merge was requested.' }
          end
        end
      end

      context 'when the merge request is not the first queue' do
        before do
          allow(merge_request.merge_train_car).to receive(:effectively_first_car?).and_return(false)
        end

        it 'does not merge the merge request' do
          expect(MergeRequests::MergeService).not_to receive(:new)

          subject
        end
      end
    end
  end
end
