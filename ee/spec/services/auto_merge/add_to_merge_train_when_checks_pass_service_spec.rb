# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AutoMerge::AddToMergeTrainWhenChecksPassService, feature_category: :code_review_workflow do
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, maintainer_of: project) }

  let(:service) { described_class.new(project, user) }

  let(:merge_request) do
    create(:merge_request, :with_merge_request_pipeline,
      source_project: project, source_branch: 'feature',
      target_project: project, target_branch: 'master')
  end

  let(:pipeline) { merge_request.reload.all_pipelines.first }

  before do
    project.update!(merge_pipelines_enabled: true, merge_trains_enabled: true)
    stub_licensed_features(merge_trains: true, merge_pipelines: true)
    allow(AutoMergeProcessWorker).to receive(:perform_async).and_return(nil)
    merge_request.update_head_pipeline
  end

  describe '#execute' do
    subject(:execute) { service.execute(merge_request) }

    it 'enables auto merge' do
      expect(SystemNoteService)
        .to receive(:add_to_merge_train_when_checks_pass)
        .with(merge_request, project, user, merge_request.diff_head_pipeline.sha)

      execute

      expect(merge_request).to be_auto_merge_enabled
    end

    context 'when diff_head_pipeline is nil (pipeline creating)' do
      before do
        allow(merge_request).to receive(:diff_head_pipeline).and_return(nil)
      end

      it 'enables auto merge using diff_head_sha' do
        expect(SystemNoteService)
          .to receive(:add_to_merge_train_when_checks_pass)
          .with(merge_request, project, user, merge_request.diff_head_sha)

        execute

        expect(merge_request).to be_auto_merge_enabled
      end
    end
  end

  describe '#process' do
    subject(:process) { service.process(merge_request) }

    before do
      service.execute(merge_request)
    end

    context 'when the merge request has ci enabled' do
      context 'when the latest pipeline in the merge request has succeeded' do
        before do
          pipeline.succeed!
        end

        context 'when its mergeable' do
          it 'executes MergeTrainService' do
            expect_next_instance_of(AutoMerge::MergeTrainService) do |train_service|
              expect(train_service).to receive(:execute).with(merge_request)
            end

            process
          end

          context 'when user does not have permission to merge the merge request' do
            before do
              allow(merge_request).to receive(:can_be_merged_by?).with(user).and_return(false)
            end

            it 'aborts auto merge' do
              expect(service).to receive(:abort).once.and_call_original

              expect(SystemNoteService)
                .to receive(:abort_add_to_merge_train_when_checks_pass).once
                .with(merge_request, project, user, 'they do not have permission to merge the merge request.')

              process
            end
          end

          context 'when mergeability checks do not pass' do
            let(:identifier) { 'failed_check' }
            let(:failed_result) do
              Gitlab::MergeRequests::Mergeability::CheckResult.failed(payload: { identifier: identifier })
            end

            before do
              allow_next_instance_of(MergeRequests::Mergeability::CheckOpenStatusService) do |service|
                allow(service).to receive_messages(skip?: false, execute: failed_result)
              end
              allow(merge_request).to receive(:mergeable?).and_return(true)
            end

            it 'aborts auto merge' do
              expect(service).to receive(:abort).once.and_call_original

              expect(SystemNoteService)
                .to receive(:abort_add_to_merge_train_when_checks_pass).once
                .with(
                  merge_request,
                  project,
                  user,
                  "the merge request cannot be merged. Failed mergeability check: #{identifier}"
                )

              process
            end
          end

          context 'when merge trains are not enabled' do
            before do
              allow(merge_request.project).to receive(:merge_trains_enabled?).and_return(false)
            end

            it 'aborts auto merge' do
              expect(service).to receive(:abort).once.and_call_original

              expect(SystemNoteService)
                .to receive(:abort_add_to_merge_train_when_checks_pass).once
                .with(merge_request, project, user, 'merge trains are disabled for this project.')

              process
            end
          end

          context 'when project is not licensed for merge trains' do
            before do
              stub_licensed_features(merge_trains: false)
            end

            it 'aborts auto merge' do
              expect(service).to receive(:abort).once.and_call_original

              expect(SystemNoteService)
                .to receive(:abort_add_to_merge_train_when_checks_pass).once
                .with(merge_request, project, user, 'merge trains are disabled for this project.')

              process
            end
          end

          context 'when diff head pipeline considered in progress' do
            before do
              allow(merge_request).to receive(:only_allow_merge_if_pipeline_succeeds?).and_return(true)
              allow(merge_request.diff_head_pipeline).to receive(:complete?).and_return(false)
            end

            it 'aborts auto merge' do
              expect(service).to receive(:abort).once.and_call_original
              expect(SystemNoteService)
                .to receive(:abort_add_to_merge_train_when_checks_pass).once
                .with(merge_request, project, user, 'the merge request currently has a pipeline in progress.')

              process
            end
          end

          context 'when MergeTrainService is not available_for mr but reason is unknown' do
            before do
              allow_next_instance_of(AutoMerge::MergeTrainService) do |mr_service|
                allow(mr_service).to receive(:available_for?).and_return(false)
              end
            end

            it 'aborts auto merge' do
              expect(service).to receive(:abort).once.and_call_original
              expect(SystemNoteService)
                .to receive(:abort_add_to_merge_train_when_checks_pass).once
                .with(merge_request, project, user, 'this merge request cannot be added to the merge train.')

              process
            end
          end
        end

        context 'when its not mergeable' do
          context 'when the MR is unchecked' do
            it 'executes MergeTrainService' do
              merge_request.mark_as_unchecked!

              expect_next_instance_of(AutoMerge::MergeTrainService) do |train_service|
                expect(train_service).to receive(:execute).with(merge_request)
              end

              process
            end
          end

          it 'does not initialize MergeTrainService' do
            merge_request.update!(title: merge_request.draft_title)
            expect(AutoMerge::MergeTrainService).not_to receive(:new)

            process
          end
        end
      end

      context 'when the latest pipeline has not succeeded' do
        it 'does not initialize MergeTrainService' do
          merge_request.update!(title: merge_request.draft_title)
          expect(AutoMerge::MergeTrainService).not_to receive(:new)

          process
        end
      end
    end

    context 'when pipeline is skipped' do
      before do
        pipeline.skip!
        project.update!(only_allow_merge_if_pipeline_succeeds: true)
      end

      context 'when allow_merge_on_skipped_pipeline is enabled' do
        before do
          project.update!(allow_merge_on_skipped_pipeline: true)
        end

        it 'executes MergeTrainService' do
          expect_next_instance_of(AutoMerge::MergeTrainService) do |train_service|
            expect(train_service).to receive(:execute).with(merge_request)
          end

          process
        end
      end

      context 'when allow_merge_on_skipped_pipeline is disabled' do
        before do
          project.update!(allow_merge_on_skipped_pipeline: false)
        end

        it 'does not initialize MergeTrainService' do
          expect(AutoMerge::MergeTrainService).not_to receive(:new)

          process
        end
      end
    end
  end

  describe '#cancel' do
    subject(:cancel) { service.cancel(merge_request) }

    let(:merge_request) { create(:merge_request, :add_to_merge_train_when_checks_pass, merge_user: user) }

    it 'cancels auto merge' do
      expect(SystemNoteService)
        .to receive(:cancel_add_to_merge_train_when_checks_pass)
        .with(merge_request, project, user)

      cancel

      expect(merge_request).not_to be_auto_merge_enabled
    end
  end

  describe '#abort' do
    subject(:abort_call) { service.abort(merge_request, 'an error') }

    let(:merge_request) { create(:merge_request, :add_to_merge_train_when_checks_pass, merge_user: user) }

    context 'without merge train car' do
      it 'disables the auto-merge' do
        expect(SystemNoteService)
          .to receive(:abort_add_to_merge_train_when_checks_pass)
                .with(merge_request, project, user, 'an error')

        abort_call

        expect(merge_request).not_to be_auto_merge_enabled
      end
    end

    context 'with merge train car' do
      let(:merge_train_car) { create(:merge_train_car, merge_request: merge_request, target_project: project) }

      it 'aborts by destroying the running train car and canceling the pipeline' do
        expect(merge_train_car).not_to be_nil
        expect(SystemNoteService)
          .to receive(:abort_merge_train)
                .with(merge_request, project, user, 'an error')

        abort_call

        expect(merge_request).not_to be_auto_merge_enabled
        expect(merge_request.reload.merge_train_car).to be_nil
      end
    end
  end

  describe '#available_for?' do
    let(:mr_messages) { {} }

    subject(:available_for) { service.available_for?(merge_request) }

    before do
      allow(merge_request).to receive_messages(**mr_messages) if mr_messages.any?
    end

    it { is_expected.to be(true) }

    context 'when merge trains option is disabled' do
      before do
        allow(merge_request.project).to receive(:merge_trains_enabled?).and_return(false)
      end

      it { is_expected.to be(false) }
    end

    context 'when the MR does not have ci enabled' do
      let(:mr_messages) { { has_ci_enabled?: false } }

      it { is_expected.to be(false) }
    end

    context 'when merge request is not mergeable' do
      before do
        merge_request.update!(title: merge_request.draft_title)
      end

      it { is_expected.to be(true) }
    end

    context 'when the user does not have permission to merge' do
      let(:mr_messages) { { can_be_merged_by?: false } }

      it { is_expected.to be(false) }
    end

    context 'when pipeline is being created' do
      let(:mr_messages) { { pipeline_creating?: true } }

      it { is_expected.to be(true) }
    end

    context 'when merge request is mergeable and pipeline is not in progress' do
      before do
        allow(merge_request).to receive_messages(mergeable?: true, diff_head_pipeline_considered_in_progress?: false)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#availability_details' do
    subject(:availability_check) { service.availability_details(merge_request) }

    it 'is available and has no unavailable reason', :aggregate_failures do
      expect(availability_check.available?).to be true
      expect(availability_check.unavailable_reason).to be_nil
    end

    it 'memoizes the result' do
      expect(service).to receive(:availability_details).once.and_call_original

      2.times { is_expected.to be_truthy }
    end

    context 'when merge trains option is disabled' do
      before do
        allow(merge_request.project).to receive(:merge_trains_enabled?).and_return(false)
      end

      it 'is unavailable and returns the correct reason', :aggregate_failures do
        expect(availability_check.available?).to be false
        expect(availability_check.unavailable_reason).to eq :merge_trains_disabled
      end
    end

    context 'when project is not licensed for merge trains' do
      before do
        stub_licensed_features(merge_trains: false)
      end

      it 'is unavailable and returns the correct reason', :aggregate_failures do
        expect(availability_check.available?).to be false
        expect(availability_check.unavailable_reason).to eq :merge_trains_disabled
      end
    end

    context 'when the MR does not have ci enabled' do
      before do
        allow(merge_request).to receive(:has_ci_enabled?).and_return(false)
      end

      it 'is unavailable and returns the correct reason', :aggregate_failures do
        expect(availability_check.available?).to be false
        expect(availability_check.unavailable_reason).to eq :default
      end
    end

    context 'when merge request is not mergeable' do
      before do
        merge_request.update!(title: merge_request.draft_title)
      end

      it 'is available and has no unavailable reason', :aggregate_failures do
        expect(availability_check.available?).to be true
        expect(availability_check.unavailable_reason).to be_nil
      end
    end

    context 'when the user does not have permission to merge' do
      before do
        allow(merge_request).to receive(:can_be_merged_by?).and_return(false)
      end

      it 'is unavailable and returns the correct reason', :aggregate_failures do
        expect(availability_check.available?).to be false
        expect(availability_check.unavailable_reason).to eq :forbidden
      end
    end

    context 'when pipeline is being created' do
      before do
        allow(merge_request).to receive(:pipeline_creating?).and_return(true)
      end

      it 'is available and has no unavailable reason', :aggregate_failures do
        expect(availability_check.available?).to be true
        expect(availability_check.unavailable_reason).to be_nil
      end
    end

    context 'when merge request is mergeable and pipeline is not in progress' do
      before do
        allow(merge_request).to receive_messages(mergeable?: true, diff_head_pipeline_considered_in_progress?: false)
      end

      it 'is unavailable and returns the correct reason', :aggregate_failures do
        expect(availability_check.available?).to be false
        expect(availability_check.unavailable_reason).to eq :default
      end
    end
  end
end
