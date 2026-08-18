# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTriggers::CreateNoteService, feature_category: :duo_agent_platform do
  let_it_be_with_refind(:project) { create(:project, :repository) }
  let_it_be(:author) { create(:service_account, maintainer_of: project, name: 'Author Name') }
  let_it_be(:resource) { create(:issue, project: project) }
  let_it_be(:existing_note) { create(:note, project: project, noteable: resource) }
  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:discussion, freeze: false) { existing_note.discussion }

  let(:params) { { input: 'test input', event: 'mention' } }

  subject(:service) do
    described_class.new(
      project: project,
      resource: resource,
      author: author,
      discussion: discussion
    )
  end

  describe '#create_note' do
    it 'creates a processing note in the discussion' do
      expect(Notes::CreateService).to receive(:new).with(
        project,
        author,
        note: s_('AiFlowTriggers|🔄 Processing the request...'),
        noteable: resource,
        in_reply_to_discussion_id: discussion.id
      ).and_call_original

      note = service.create_note

      expect(note).to be_persisted
    end

    context 'when no discussion is provided' do
      subject(:service) do
        described_class.new(
          project: project,
          resource: resource,
          author: author,
          discussion: nil
        )
      end

      it 'creates note without in_reply_to_discussion_id' do
        expect(Notes::CreateService).to receive(:new).with(
          project,
          author,
          note: s_('AiFlowTriggers|🔄 Processing the request...'),
          noteable: resource,
          in_reply_to_discussion_id: nil
        ).and_call_original

        service.create_note
      end
    end
  end

  describe '#mark_started' do
    let_it_be(:workflow_workload) { create(:duo_workflows_workload, project: project) }
    # `freeze: false` is required in this spec: one or more `let_it_be` subjects
    # cannot be frozen by default (deep_freeze traversal failure, a non-AR
    # subject, or an in-memory mutation that survives reload/refind). Do not
    # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
    # (see gitlab-org/gitlab#602925).
    let_it_be(:workflow, freeze: false) { workflow_workload.workflow }
    let(:note) { create(:note, project: project, noteable: resource, author: author) }

    it 'updates the note with a success message and workflow link' do
      service.mark_started(note, workflow)

      note.reload
      expect(note.note).to include('✅ Author Name has started. You can view progress')
      expect(note.note).to include("agent-sessions/#{workflow.id}")
      expect(note.note).to include('target="_blank" rel="noopener noreferrer"')
    end

    context 'when the author name contains HTML' do
      before do
        allow(author).to receive(:name).and_return('Hacker <a>Person</a>')
      end

      it 'safely escapes the name' do
        service.mark_started(note, workflow)

        note.reload
        expect(note.note).to include('✅ Hacker &lt;a&gt;Person&lt;/a&gt; has started.')
      end
    end

    context 'when the note is not persisted' do
      let(:note) { build(:note, project: project, noteable: resource) }

      it 'does not attempt to update' do
        expect(note).not_to receive(:update)

        service.mark_started(note, workflow)
      end
    end

    context 'when note update fails' do
      let(:mock_logger) { Ai::Catalog::Logger.build }

      before do
        allow(note).to receive_messages(
          persisted?: true,
          update: false,
          errors: instance_double(ActiveModel::Errors, full_messages: ['Note is too long'])
        )

        allow(Ai::Catalog::Logger).to receive(:build).and_return(mock_logger)
        allow(mock_logger).to receive(:context).and_return(mock_logger)
        allow(mock_logger).to receive(:error)
      end

      it 'logs the failure' do
        service.mark_started(note, workflow)

        expect(mock_logger).to have_received(:error).with(
          hash_including(
            message: 'Failed to update processing note',
            note_id: note.id
          )
        )
      end
    end
  end

  describe '#mark_failed' do
    let(:note) { create(:note, project: project, noteable: resource, author: author) }

    it 'updates the note with a sanitized error message' do
      service.mark_failed(note, 'Something went wrong')

      note.reload
      expect(note.note).to include('❌ Could not start processing due to this error: Something went wrong')
    end

    it 'sanitizes HTML in error messages' do
      service.mark_failed(note, '<script>alert("xss")</script>')

      note.reload
      expect(note.note).to include('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;')
      expect(note.note).not_to include('<script>')
    end

    it 'handles array error messages by joining them' do
      service.mark_failed(note, ['first error', 'second error'])

      note.reload
      expect(note.note).to include('first error, second error')
    end

    it 'truncates long error messages to 200 characters' do
      long_error = 'x' * 300

      service.mark_failed(note, long_error)

      note.reload
      # The truncated error should be at most 200 chars (including the "..." suffix)
      error_part = note.note.split('error: ').last
      expect(error_part.length).to be <= 200
      expect(error_part).to end_with('...')
    end

    context 'when the note is not persisted' do
      let(:note) { build(:note, project: project, noteable: resource) }

      it 'does not attempt to update' do
        expect(note).not_to receive(:update)

        service.mark_failed(note, 'error')
      end
    end

    context 'when note update fails' do
      let(:mock_logger) { Ai::Catalog::Logger.build }

      before do
        allow(note).to receive_messages(
          persisted?: true,
          update: false,
          errors: instance_double(ActiveModel::Errors, full_messages: ['Note is too long'])
        )

        allow(Ai::Catalog::Logger).to receive(:build).and_return(mock_logger)
        allow(mock_logger).to receive(:context).and_return(mock_logger)
        allow(mock_logger).to receive(:error)
      end

      it 'logs the failure' do
        service.mark_failed(note, 'error')

        expect(mock_logger).to have_received(:error).with(
          hash_including(
            message: 'Failed to update processing note',
            note_id: note.id
          )
        )
      end
    end
  end

  describe '#execute' do
    let_it_be(:workflow_workload) { create(:duo_workflows_workload, project: project) }
    let_it_be(:workflow, freeze: false) { workflow_workload.workflow }

    let(:mock_response) { ServiceResponse.success(payload: workflow_workload.workload) }

    context 'when block yields successful response' do
      it 'creates initial note, yields with discussion_id, and updates note with success message' do
        expect(Notes::CreateService).to receive(:new).with(
          project,
          author,
          note: s_('AiFlowTriggers|🔄 Processing the request...'),
          noteable: resource,
          in_reply_to_discussion_id: discussion.id
        ).and_call_original

        initial_note_count = Note.count

        response = service.execute(params) do |yielded_params|
          expect(yielded_params).to eq(params.merge(discussion_id: discussion.id))
          expect(yielded_params[:discussion_id]).to be_present

          [mock_response, workflow]
        end

        expect(response).to eq(mock_response)
        expect(Note.count).to eq(initial_note_count + 1)

        created_note = Note.last
        expect(created_note.note).to include('✅ Author Name has started. You can view progress')
        expect(created_note.note).to include("agent-sessions/#{workflow.id}")
        expect(created_note.note).to include('target="_blank" rel="noopener noreferrer"')
      end

      context 'when the username contains HTML' do
        before do
          allow(author).to receive(:name).and_return('Hacker <a>Person</a>')
        end

        it 'safely renders the name' do
          service.execute(params) do
            [mock_response, workflow]
          end

          created_note = Note.last
          expect(created_note.note).to include('✅ Hacker &lt;a&gt;Person&lt;/a&gt; has started.')
        end
      end
    end

    context 'when block yields error response' do
      let(:error_response) { ServiceResponse.error(message: 'Something went wrong') }

      it 'creates initial note and updates with error message' do
        initial_note_count = Note.count

        response = service.execute(params) { [error_response, workflow] }

        expect(response).to eq(error_response)
        expect(Note.count).to eq(initial_note_count + 1)

        created_note = Note.last
        expect(created_note.note).to include('❌ Could not start processing due to this error: Something went wrong')
      end
    end

    context 'when note creation fails' do
      let(:unpersisted_note) { build(:note, project: project, noteable: resource) }
      let(:mock_logger) { Ai::Catalog::Logger.build }

      before do
        allow_next_instance_of(Notes::CreateService) do |instance|
          allow(instance).to receive(:execute).and_return(unpersisted_note)
        end

        allow(Ai::Catalog::Logger).to receive(:build).and_return(mock_logger)
        allow(mock_logger).to receive(:context).and_return(mock_logger)
        allow(mock_logger).to receive(:error)
      end

      it 'logs the failure' do
        service.execute(params) { [mock_response, workflow] }

        expect(mock_logger).to have_received(:error).with(
          hash_including(
            message: 'Failed to create processing note',
            noteable_type: resource.class.name,
            noteable_id: resource.id
          )
        )
      end

      it 'does not attempt to update the unpersisted note' do
        expect(unpersisted_note).not_to receive(:update)

        service.execute(params) { [mock_response, workflow] }
      end
    end

    context 'when note update fails' do
      let(:persisted_note) { create(:note, project: project, noteable: resource, author: author) }
      let(:mock_logger) { Ai::Catalog::Logger.build }

      before do
        allow(persisted_note).to receive_messages(
          update: false,
          errors: instance_double(ActiveModel::Errors, full_messages: ['Note is too long'])
        )

        allow_next_instance_of(Notes::CreateService) do |instance|
          allow(instance).to receive(:execute).and_return(persisted_note)
        end

        allow(Ai::Catalog::Logger).to receive(:build).and_return(mock_logger)
        allow(mock_logger).to receive(:context).and_return(mock_logger)
        allow(mock_logger).to receive(:error)
      end

      it 'logs the failure with the error details' do
        service.execute(params) { [mock_response, workflow] }

        expect(mock_logger).to have_received(:error).with(
          hash_including(
            message: 'Failed to update processing note',
            note_id: persisted_note.id,
            errors: 'Note is too long'
          )
        )
      end
    end

    context 'when no discussion is provided' do
      subject(:service) do
        described_class.new(
          project: project,
          resource: resource,
          author: author,
          discussion: nil
        )
      end

      it 'creates note without in_reply_to_discussion_id' do
        expect(Notes::CreateService).to receive(:new).with(
          project,
          author,
          note: s_('AiFlowTriggers|🔄 Processing the request...'),
          noteable: resource,
          in_reply_to_discussion_id: nil
        ).and_call_original

        service.execute(params) { [mock_response, workflow] }
      end
    end

    context 'when resource is a merge request' do
      let_it_be(:merge_request) do
        create(:merge_request,
          source_project: project,
          target_project: project,
          source_branch: 'feature-branch',
          target_branch: 'main'
        )
      end

      let_it_be(:resource) { merge_request }

      it 'creates note on merge request' do
        expect(Notes::CreateService).to receive(:new).with(
          project,
          author,
          note: s_('AiFlowTriggers|🔄 Processing the request...'),
          noteable: merge_request,
          in_reply_to_discussion_id: discussion.id
        ).and_call_original

        service.execute(params) { [mock_response, workflow] }
      end
    end
  end
end
