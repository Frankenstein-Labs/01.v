# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AmazonQ::RequestPayload, feature_category: :ai_agents do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:merge_request) { create(:merge_request_with_diffs, source_project: project) }
  let_it_be(:work_item) { create(:work_item, :issue, project: project) }
  let_it_be(:note_on_issue) { create(:note_on_issue, noteable: issue, project: project) }
  let_it_be(:note_on_merge_request) { create(:note_on_merge_request, noteable: merge_request, project: project) }

  let(:command) { 'dev' }
  let(:note) { note_on_issue }
  let(:discussion_id) { note_on_issue.discussion_id }
  let(:source) { issue }
  let(:service_account_notes) { [] }
  let(:input) { "input" }
  let(:line_position_for_comment) { { comment_start_line: "14", comment_end_line: "15" } }

  subject(:request_payload) do
    described_class.new(
      command: command,
      note: note,
      source: source,
      service_account_notes: service_account_notes,
      discussion_id: discussion_id,
      input: input,
      line_position_for_comment: line_position_for_comment
    )
  end

  describe '#payload' do
    context 'when the source is an issue' do
      it 'generates the correct payload for an issue' do
        payload = request_payload.payload

        expect(payload[:command]).to eq(command)
        expect(payload[:source]).to eq('issue')
        expect(payload[:project_path]).to eq(project.full_path)
        expect(payload[:project_id]).to eq(project.id.to_s)
        expect(payload[:issue_id]).to eq(issue.id.to_s)
        expect(payload[:issue_iid]).to eq(issue.iid.to_s)
        expect(payload[:discussion_id]).to eq(discussion_id)
      end
    end

    context 'when the source is a work item' do
      let(:source) { work_item }

      it 'generates the correct payload for an issue' do
        payload = request_payload.payload

        expect(payload[:command]).to eq(command)
        expect(payload[:source]).to eq('issue')
        expect(payload[:project_path]).to eq(project.full_path)
        expect(payload[:project_id]).to eq(project.id.to_s)
        expect(payload[:issue_id]).to eq(work_item.id.to_s)
        expect(payload[:issue_iid]).to eq(work_item.iid.to_s)
        expect(payload[:discussion_id]).to eq(discussion_id)
      end
    end

    context 'when the source is a merge request' do
      let(:source) { merge_request }
      let(:note) { note_on_merge_request }

      it 'generates the correct payload for a merge request' do
        payload = request_payload.payload

        expect(payload[:command]).to eq(command)
        expect(payload[:source]).to eq('merge_request')
        expect(payload[:project_path]).to eq(project.full_path)
        expect(payload[:project_id]).to eq(project.id.to_s)
        expect(payload[:merge_request_id]).to eq(merge_request.id.to_s)
        expect(payload[:merge_request_iid]).to eq(merge_request.iid.to_s)
      end
    end

    context 'when the command is "test" and note is a DiffNote' do
      let(:command) { 'test' }
      let(:source) { merge_request }
      let(:note) { build(:diff_note_on_merge_request, noteable: merge_request, project: project) }

      it 'generates the correct test command payload' do
        payload = request_payload.payload

        expect(payload[:command]).to eq('test')
        expect(payload[:start_sha]).to eq(note.position.start_sha)
        expect(payload[:head_sha]).to eq(note.position.head_sha)
        expect(payload[:file_path]).to eq(note.position.new_path)
        expect(payload[:user_message]).to eq(input.to_s)
        expect(payload[:comment_start_line]).to eq("14")
        expect(payload[:comment_end_line]).to eq("15")
      end
    end

    context 'when using an existing thread' do
      let(:service_account_notes) { [note_on_issue] }
      let(:command) { 'dev' }

      it 'generates the correct note payload when using an existing thread' do
        payload = request_payload.payload

        expect(payload[:note_id]).to eq(note_on_issue.id.to_s)
        expect(payload[:discussion_id]).to eq(discussion_id)
      end
    end

    context 'when using a new thread' do
      let(:service_account_notes) { [] }
      let(:command) { 'dev' }

      it 'generates the correct note payload when using a new thread' do
        allow(request_payload).to receive(:use_existing_thread?).and_return(false)

        payload = request_payload.payload

        expect(payload[:note_id]).to eq(request_payload.instance_variable_get(:@progress_note)&.id.to_s)
        expect(payload[:discussion_id]).to eq(discussion_id)
      end
    end

    context 'when there is an ArgumentError in payload generation' do
      before do
        allow(request_payload).to receive(:base_payload).and_raise(ArgumentError, 'Test error')
      end

      it 'logs the error and raises it' do
        expect(Gitlab::AppLogger).to receive(:error).with(message: "[amazon_q] ArgumentError: Test error")

        expect { request_payload.payload }.to raise_error(ArgumentError, 'Test error')
      end
    end
  end

  describe '#base_payload' do
    it 'includes the correct basic fields' do
      base_payload = request_payload.send(:base_payload)

      expect(base_payload[:command]).to eq(command)
      expect(base_payload[:role_arn]).to eq(Ai::Setting.for_organization_read_only(project.organization).amazon_q_role_arn)
      expect(base_payload[:project_path]).to eq(project.full_path)
      expect(base_payload[:project_id]).to eq(project.id.to_s)
    end
  end

  describe '#merge_request_payload' do
    let(:source) { merge_request }

    it 'generates the correct merge request payload' do
      merge_request_payload = request_payload.send(:merge_request_payload)

      expect(merge_request_payload[:source_branch]).to eq(merge_request.source_branch)
      expect(merge_request_payload[:target_branch]).to eq(merge_request.target_branch)
      expect(merge_request_payload[:last_commit_id]).to eq(merge_request.recent_commits&.first&.id)
    end
  end

  describe '#use_existing_thread?' do
    context 'when the command is dev, fix, review, or transform' do
      let(:command) { 'dev' }

      it 'returns true' do
        expect(request_payload.send(:use_existing_thread?)).to be true
      end
    end

    context 'when the command is not dev, fix, review, or transform' do
      let(:command) { 'other' }

      it 'returns false' do
        expect(request_payload.send(:use_existing_thread?)).to be false
      end
    end
  end
end
