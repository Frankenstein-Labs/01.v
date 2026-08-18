# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CodeReview::PublishCommentsWorker, feature_category: :duo_code_review do
  subject(:worker) { described_class.new }

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be(:user) { create(:user) }

  let(:review_output) { '<review><comment file="a.rb" old_line="" new_line="1">Fix this</comment></review>' }
  let(:workflow_id) { 42 }

  describe 'deduplication configuration' do
    it 'is idempotent' do
      expect(described_class.idempotent?).to be true
    end

    it 'uses until_executed deduplication strategy' do
      expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
    end
  end

  describe 'sidekiq_retry_in' do
    let(:progress_note) { create(:note, noteable: merge_request, project: merge_request.project) }
    let(:jobhash) do
      { 'args' => [workflow_id, merge_request.id, user.id, progress_note.id, review_output] }
    end

    it 'delegates to #track_retry with the merge_request_id and user_id from the job hash' do
      expect_next_instance_of(described_class) do |instance|
        expect(instance).to receive(:track_retry).with(merge_request.id, user.id)
      end

      described_class.sidekiq_retry_in_block.call(0, StandardError.new, jobhash)
    end

    it 'returns nil to use default exponential backoff' do
      allow_next_instance_of(described_class) { |w| allow(w).to receive(:track_retry) }

      expect(described_class.sidekiq_retry_in_block.call(0, StandardError.new, jobhash)).to be_nil
    end
  end

  describe '.idempotency_arguments' do
    it 'extracts only merge_request_id, user_id, progress_note_id, and workflow_id' do
      args = [workflow_id, merge_request.id, user.id, 123, review_output]
      result = described_class.idempotency_arguments(args)

      expect(result).to match_array([merge_request.id, user.id, 123, workflow_id])
    end

    it 'excludes review_output from idempotency key' do
      args1 = [workflow_id, merge_request.id, user.id, 123, '<review>comment 1</review>']
      args2 = [workflow_id, merge_request.id, user.id, 123, '<review>comment 2</review>']

      result1 = described_class.idempotency_arguments(args1)
      result2 = described_class.idempotency_arguments(args2)

      expect(result1).to eq(result2)
    end

    it 'handles nil workflow_id' do
      args = [nil, merge_request.id, user.id, 123, review_output]
      result = described_class.idempotency_arguments(args)

      expect(result).to match_array([merge_request.id, user.id, 123, nil])
    end
  end

  describe '#perform' do
    context 'when merge request does not exist' do
      it 'returns early without calling CreateCommentsService' do
        expect(Ai::DuoWorkflows::CodeReview::CreateCommentsService).not_to receive(:new)

        worker.perform(workflow_id, non_existing_record_id, user.id, non_existing_record_id, review_output)
      end
    end

    context 'when user does not exist' do
      it 'returns early without calling CreateCommentsService' do
        expect(Ai::DuoWorkflows::CodeReview::CreateCommentsService).not_to receive(:new)

        worker.perform(workflow_id, merge_request.id, non_existing_record_id, non_existing_record_id, review_output)
      end
    end

    context 'when both merge request and user exist' do
      let(:service) { instance_double(Ai::DuoWorkflows::CodeReview::CreateCommentsService) }
      let(:progress_note) { create(:note, noteable: merge_request, project: merge_request.project) }

      before do
        allow(Ai::DuoWorkflows::CodeReview::CreateCommentsService)
          .to receive(:new)
          .with(
            user: user,
            merge_request: merge_request,
            review_output: review_output,
            progress_note: progress_note,
            workflow_id: workflow_id
          )
          .and_return(service)
        allow(service).to receive(:execute).and_return(ServiceResponse.success)
      end

      it 'fetches the progress note by ID and delegates to CreateCommentsService', :aggregate_failures do
        expect(Note).to receive(:find_by_id).with(progress_note.id).and_return(progress_note)
        expect(service).to receive(:execute).and_return(ServiceResponse.success)

        worker.perform(workflow_id, merge_request.id, user.id, progress_note.id, review_output)
      end

      it 'passes nil progress_note when note is not found' do
        allow(Ai::DuoWorkflows::CodeReview::CreateCommentsService)
          .to receive(:new)
          .with(user: user, merge_request: merge_request, review_output: review_output,
            progress_note: nil, workflow_id: workflow_id)
          .and_return(service)

        expect(service).to receive(:execute).and_return(ServiceResponse.success)

        worker.perform(workflow_id, merge_request.id, user.id, non_existing_record_id, review_output)
      end

      it 'emits a publish event with succeeded status on successful execution' do
        expect { worker.perform(workflow_id, merge_request.id, user.id, progress_note.id, review_output) }
          .to trigger_internal_events('publish_duo_code_review_comments')
          .with(user: user, project: merge_request.project, additional_properties: { status: 'succeeded' })
      end

      context 'when CreateCommentsService returns a failure response' do
        before do
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'failed'))
        end

        it 'emits a publish event with failed status' do
          expect { worker.perform(workflow_id, merge_request.id, user.id, progress_note.id, review_output) }
            .to trigger_internal_events('publish_duo_code_review_comments')
            .with(user: user, project: merge_request.project, additional_properties: { status: 'failed' })
        end
      end
    end

    context 'when CreateCommentsService raises a StandardError' do
      before do
        allow(Ai::DuoWorkflows::CodeReview::CreateCommentsService)
          .to receive(:new)
          .and_raise(StandardError, 'something went wrong')
      end

      it 'tracks the exception and re-raises so Sidekiq can retry', :aggregate_failures do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(StandardError),
          merge_request_id: merge_request.id,
          user_id: user.id
        )

        expect do
          worker.perform(workflow_id, merge_request.id, user.id, non_existing_record_id, review_output)
        end.to raise_error(StandardError, 'something went wrong')
      end

      it 'does not emit publish event when an exception is raised (lets retry handler track it)' do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)

        expect do
          worker.perform(workflow_id, merge_request.id, user.id, non_existing_record_id, review_output)
        rescue StandardError
          nil
        end.not_to trigger_internal_events('publish_duo_code_review_comments')
      end
    end
  end

  describe '#track_retry' do
    it 'emits a publish event with retry status' do
      expect { worker.track_retry(merge_request.id, user.id) }
        .to trigger_internal_events('publish_duo_code_review_comments')
        .with(user: user, project: merge_request.project, additional_properties: { status: 'retry' })
    end

    context 'when merge request does not exist' do
      it 'does not emit an event' do
        expect { worker.track_retry(non_existing_record_id, user.id) }
          .not_to trigger_internal_events('publish_duo_code_review_comments')
      end
    end

    context 'when user does not exist' do
      it 'does not emit an event' do
        expect { worker.track_retry(merge_request.id, non_existing_record_id) }
          .not_to trigger_internal_events('publish_duo_code_review_comments')
      end
    end
  end

  describe '#perform_failure' do
    let_it_be(:review_bot) { create(:user, :duo_code_review_bot) }

    before do
      allow_next_instance_of(Users::Internal) do |instance|
        allow(instance).to receive(:duo_code_review_bot).and_return(review_bot)
      end
    end

    context 'when merge request does not exist' do
      it 'returns early without posting a note' do
        expect(Notes::CreateService).not_to receive(:new)

        worker.perform_failure(non_existing_record_id, user.id)
      end
    end

    context 'when user does not exist' do
      it 'returns early without posting a note' do
        expect(Notes::CreateService).not_to receive(:new)

        worker.perform_failure(merge_request.id, non_existing_record_id)
      end
    end

    context 'when both merge request and user exist' do
      it 'emits a publish event with exhausted status' do
        allow(Notes::CreateService).to receive_message_chain(:new, :execute)

        expect { worker.perform_failure(merge_request.id, user.id) }
          .to trigger_internal_events('publish_duo_code_review_comments')
          .with(user: user, project: merge_request.project, additional_properties: { status: 'exhausted' })
      end

      it 'posts an error note to the MR using the review bot', :aggregate_failures do
        allow(worker).to receive(:track_internal_event)

        expect(Notes::CreateService).to receive(:new).with(
          merge_request.project,
          review_bot,
          noteable: merge_request,
          note: ::Gitlab::Duo::CodeReview::Messages.publish_comments_exhausted_error
        ).and_return(instance_double(Notes::CreateService, execute: true))

        worker.perform_failure(merge_request.id, user.id)
      end
    end
  end
end
