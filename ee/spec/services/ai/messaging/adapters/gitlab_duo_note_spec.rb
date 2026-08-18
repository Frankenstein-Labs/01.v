# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Messaging::Adapters::GitlabDuoNote, feature_category: :duo_code_review do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be(:author) { create(:user) }
  let_it_be(:note) do
    create(:diff_note_on_merge_request, noteable: merge_request, project: project, author: author)
  end

  let_it_be(:duo_bot) { ::Users::Internal.in_organization(project.organization_id).duo_code_review_bot }

  let(:ctx) do
    {
      'note_id' => note.id,
      'note_author_id' => duo_bot.id
    }
  end

  subject(:adapter) { described_class.from_callback_context(ctx) }

  describe '.adapter_key' do
    it { expect(described_class.adapter_key).to eq('gitlab_duo_note') }
  end

  describe '.for_note' do
    it 'builds an adapter that serializes the note id and author id' do
      adapter = described_class.for_note(note, note_author_id: duo_bot.id)

      expect(adapter.build_callback_context).to eq(
        'adapter' => 'gitlab_duo_note',
        'note_id' => note.id,
        'note_author_id' => duo_bot.id
      )
    end
  end

  describe '.from_callback_context' do
    it 'returns an instance of the adapter' do
      expect(described_class.from_callback_context(ctx)).to be_a(described_class)
    end
  end

  describe '#on_request_received' do
    it 'returns ServiceResponse.success' do
      expect(adapter.on_request_received).to be_success
    end

    context 'when note is not found' do
      let(:ctx) { super().merge('note_id' => non_existing_record_id) }

      it 'returns ServiceResponse.error' do
        result = adapter.on_request_received

        expect(result).to be_error
        expect(result.message).to eq('Note not found')
      end
    end

    context 'when the note has no noteable' do
      before do
        allow_next_found_instance_of(Note) do |found_note|
          allow(found_note).to receive(:noteable).and_return(nil)
        end
      end

      it 'returns ServiceResponse.error' do
        result = adapter.on_request_received

        expect(result).to be_error
        expect(result.message).to eq('Noteable not found')
      end
    end
  end

  describe '#on_flow_enqueued' do
    let_it_be_with_reload(:workflow) { create(:duo_workflows_workflow, project: project, user: author) }

    it 'posts a duo_mention_started note in the discussion thread and stores its id in messaging_callback_context',
      :aggregate_failures do
      adapter.on_flow_enqueued(callback_context: ctx, workflow: workflow)

      started_note = Note.order(id: :desc).first
      expect(started_note.note).to include('started [session')
      expect(started_note.author).to eq(duo_bot)
      expect(started_note.discussion_id).to eq(note.discussion_id)
      expect(workflow.reload.messaging_callback_context['started_note_id']).to eq(started_note.id)
    end

    context 'when note is not found' do
      let(:ctx) { super().merge('note_id' => non_existing_record_id) }

      it 'does nothing' do
        expect { adapter.on_flow_enqueued(callback_context: ctx, workflow: workflow) }
          .not_to change { Note.count }
      end
    end

    context 'when author is not found' do
      let(:ctx) { super().merge('note_author_id' => non_existing_record_id) }

      it 'does nothing' do
        expect { adapter.on_flow_started(callback_context: ctx, workflow: workflow) }
          .not_to change { Note.count }
      end
    end
  end

  describe '#build_callback_context' do
    it 'returns a hash with adapter key, note_id, and note_author_id' do
      result = adapter.build_callback_context

      expect(result).to eq(
        'adapter' => 'gitlab_duo_note',
        'note_id' => note.id,
        'note_author_id' => duo_bot.id
      )
    end
  end

  describe '#deliver_result' do
    it 'posts a reply note in the original discussion', :aggregate_failures do
      expect { adapter.deliver_result(callback_context: ctx, message: 'Review done!', workflow: nil) }
        .to change { Note.count }.by(1)

      reply = Note.order(id: :desc).first
      expect(reply.note).to eq('Review done!')
      expect(reply.author).to eq(duo_bot)
      expect(reply.noteable).to eq(merge_request)
    end

    it 'returns true once the reply note is persisted' do
      expect(adapter.deliver_result(callback_context: ctx, message: 'Review done!', workflow: nil)).to be(true)
    end

    context 'when the reply note is rejected' do
      before do
        allow_next_instance_of(::Notes::CreateService) do |service|
          allow(service).to receive(:execute).and_return(build(:note))
        end
      end

      it 'returns false so the caller can retry the delivery' do
        expect(adapter.deliver_result(callback_context: ctx, message: 'Review done!', workflow: nil)).to be(false)
      end
    end

    it 'links the author composite identity to the original mentioner before posting' do
      # A composite-identity service-account author (e.g. the Duo Developer flow
      # SA) cannot post the reply in CallbackWorker without a linked human.
      expect(adapter).to receive(:link_composite_identity!)
        .with(duo_bot, note.author, note.project.organization).and_call_original

      adapter.deliver_result(callback_context: ctx, message: 'Review done!', workflow: nil)
    end

    context 'when started_note_id is present in callback_context' do
      let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: author) }
      let!(:started_note) do
        create(:note, project: project, noteable: merge_request).tap do |n|
          create(:note_duo_metadata, note: n, workflow_id: workflow.id, namespace_id: project.namespace_id)
        end
      end

      let(:ctx_with_started) { ctx.merge('started_note_id' => started_note.id) }

      it 'destroys the started note (removes the thinking message)' do
        expect { adapter.deliver_result(callback_context: ctx_with_started, message: 'Done', workflow: workflow) }
          .to change { Note.exists?(started_note.id) }.from(true).to(false)
      end

      it 'appends a session link to the reply note' do
        adapter.deliver_result(callback_context: ctx_with_started, message: 'Done', workflow: workflow)

        reply = Note.order(id: :desc).first
        expect(reply.note).to include('Done')
        expect(reply.note).to include("[View session](#{workflow.web_url})")
      end

      it 'records a created link from the workflow to the reply note', :aggregate_failures do
        expect { adapter.deliver_result(callback_context: ctx_with_started, message: 'Done', workflow: workflow) }
          .to change { Ai::DuoWorkflows::WorkflowNote.count }.by(1)

        reply = Note.order(id: :desc).first
        link = Ai::DuoWorkflows::WorkflowNote.order(:id).last
        expect(link).to have_attributes(
          workflow: workflow,
          note_id: reply.id,
          link_type: 'created'
        )
      end

      it 'does not fail delivery when linking raises', :aggregate_failures do
        allow(::Ai::DuoWorkflows::LinkArtifactService).to receive(:new).and_raise(StandardError)
        expect(::Gitlab::ErrorTracking).to receive(:track_exception)

        # started_note is destroyed (-1) and the reply is created (+1), so Note.count nets to 0.
        expect { adapter.deliver_result(callback_context: ctx_with_started, message: 'Done', workflow: workflow) }
          .to not_change { Note.count }
          .and not_change { Ai::DuoWorkflows::WorkflowNote.count }

        reply = Note.order(id: :desc).first
        expect(reply.note).to include('Done')
      end

      context 'when destroying the started note fails' do
        before do
          allow_next_found_instance_of(::Note) do |n|
            allow(n).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed)
          end
        end

        it 'tracks the error and still posts the reply' do
          expect(::Gitlab::ErrorTracking).to receive(:track_exception)
            .with(instance_of(ActiveRecord::RecordNotDestroyed), note_id: started_note.id)

          expect { adapter.deliver_result(callback_context: ctx_with_started, message: 'Done', workflow: workflow) }
            .to change { Note.count }.by(1)
        end
      end
    end

    context 'when message is blank' do
      it 'does not create a note when there is no workflow (no session link to append)' do
        expect { adapter.deliver_result(callback_context: ctx, message: '', workflow: nil) }
          .not_to change { Note.count }
      end

      context 'when started_note_id is present (workflow available)' do
        let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: author) }
        let!(:started_note) do
          create(:note, project: project, noteable: merge_request).tap do |n|
            create(:note_duo_metadata, note: n, workflow_id: workflow.id, namespace_id: project.namespace_id)
          end
        end

        let(:ctx_with_started) { ctx.merge('started_note_id' => started_note.id) }

        it 'still posts the session link even when the result message is blank' do
          # append_session_link drops the blank message but keeps the session link,
          # so the reply note contains only the link (not swallowed by the blank-content guard).
          # Note.count stays the same: started_note is destroyed (-1) and the reply is created (+1).
          expect { adapter.deliver_result(callback_context: ctx_with_started, message: '', workflow: workflow) }
            .not_to change { Note.count }

          reply = Note.order(id: :desc).first
          expect(reply.note).to include("[View session](#{workflow.web_url})")
          expect(reply.note).not_to start_with("\n\n")
        end
      end
    end
  end

  describe '#deliver_error' do
    using RSpec::Parameterized::TableSyntax

    where(:error, :expected_text) do
      :service_account_error | 'Code Review Flow is enabled'
      :execute_workflow_failed | 'Failed to start the Duo workflow. Please try again.'
      :flow_failed | 'Something went wrong while running the task. Please try again.'
      :no_response | 'The workflow completed but no response was produced. Please try again.'
      :unknown_error | 'Something went wrong. Please try again.'
    end

    with_them do
      it 'posts the correct error note text' do
        adapter.deliver_error(callback_context: ctx.dup, error: error)

        expect(Note.order(id: :desc).first.note).to include(expected_text)
      end
    end

    context 'when started_note_id is present in callback_context' do
      let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: author) }
      let!(:started_note) do
        create(:note, project: project, noteable: merge_request).tap do |n|
          create(:note_duo_metadata, note: n, workflow_id: workflow.id, namespace_id: project.namespace_id)
        end
      end

      let(:ctx_with_started) { ctx.merge('started_note_id' => started_note.id) }

      it 'destroys the started note (removes the thinking message)' do
        expect { adapter.deliver_error(callback_context: ctx_with_started, error: :flow_failed) }
          .to change { Note.exists?(started_note.id) }.from(true).to(false)
      end

      it 'records a created link from the workflow to the error note', :aggregate_failures do
        expect { adapter.deliver_error(callback_context: ctx_with_started, error: :flow_failed) }
          .to change { Ai::DuoWorkflows::WorkflowNote.count }.by(1)

        error_note = Note.order(id: :desc).first
        link = Ai::DuoWorkflows::WorkflowNote.order(:id).last
        expect(link).to have_attributes(
          workflow: workflow,
          note_id: error_note.id,
          link_type: 'created'
        )
      end

      it 'does not fail delivery when linking raises', :aggregate_failures do
        allow(::Ai::DuoWorkflows::LinkArtifactService).to receive(:new).and_raise(StandardError)
        expect(::Gitlab::ErrorTracking).to receive(:track_exception)

        # started_note is destroyed (-1) and the error note is created (+1), so Note.count nets to 0.
        expect { adapter.deliver_error(callback_context: ctx_with_started, error: :flow_failed) }
          .to not_change { Note.count }
          .and not_change { Ai::DuoWorkflows::WorkflowNote.count }

        error_note = Note.order(id: :desc).first
        expect(error_note.note).to include('Something went wrong while running the task')
      end
    end

    context 'when started_note_id is absent (workflow has not started yet)' do
      it 'posts the error note without creating a workflow link' do
        expect { adapter.deliver_error(callback_context: ctx, error: :flow_failed) }
          .to change { Note.count }.by(1)
          .and not_change { Ai::DuoWorkflows::WorkflowNote.count }
      end
    end
  end
end
