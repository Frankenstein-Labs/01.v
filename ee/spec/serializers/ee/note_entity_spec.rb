# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NoteEntity do
  include Gitlab::Routing

  let_it_be(:issue, freeze: false) { create(:issue) }
  let_it_be(:description_version) { create(:description_version, issue: issue) }
  let_it_be(:system_note_metadata, freeze: false) { create(:system_note_metadata, description_version: description_version) }
  let_it_be(:system_note, freeze: false) do
    create(:system_note, project: issue.project, noteable: issue, system_note_metadata: system_note_metadata)
  end

  let_it_be(:plain_note) do
    create(:note, project: issue.project, noteable: issue)
  end

  let(:note) { plain_note }
  let(:request) { double('request', current_user: issue.author, noteable: issue) }
  let(:entity) { described_class.new(note, request: request) }

  subject { entity.as_json }

  describe 'duo_session_url' do
    let_it_be(:workflow) { create(:duo_workflows_workflow, project: issue.project) }
    let_it_be(:duo_metadata) do
      create(:note_duo_metadata, note: plain_note, workflow_id: workflow.id, namespace_id: issue.namespace_id)
    end

    context 'when duo agent platform is available' do
      before do
        allow(::Ai::DuoWorkflow).to receive(:duo_agent_platform_available?).and_return(true)
      end

      context 'when the note is not a system note' do
        it 'exposes the workflow web_url as duo_session_url' do
          expect(subject[:duo_session_url]).to eq(workflow.web_url)
        end

        context 'when the note has no duo_metadata' do
          let_it_be(:note_without_metadata) { create(:note, project: issue.project, noteable: issue) }

          let(:note) { note_without_metadata }

          it 'exposes duo_session_url as nil' do
            expect(subject[:duo_session_url]).to be_nil
          end
        end
      end

      context 'when the note is a system note' do
        let(:note) { system_note }

        it 'does not expose duo_session_url' do
          expect(subject.key?(:duo_session_url)).to be false
        end
      end
    end
  end

  describe 'duo_session_id', feature_category: :duo_agent_platform do
    # Note-triggered flows run in the web environment, which WorkflowPolicy treats as
    # from_pipeline? and grants to any project member with Duo access.
    let_it_be(:workflow) do
      create(:duo_workflows_workflow, project: issue.project, environment: :web)
    end

    let_it_be(:duo_metadata) do
      create(:note_duo_metadata, note: plain_note, workflow_id: workflow.id, namespace_id: issue.namespace_id)
    end

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
        .with(issue.project, :duo_workflow).and_return(true)
      allow(issue.author).to receive(:allowed_to_use?).and_return(true)
      issue.project.project_setting.update!(duo_features_enabled: true)
    end

    context 'when the current user cannot read the session' do
      let_it_be(:outsider) { create(:user) }

      let(:request) { double('request', current_user: outsider, noteable: issue) }

      it 'omits duo_session_id so the frontend does not offer a session it cannot open' do
        expect(subject.key?(:duo_session_id)).to be false
      end

      context 'when the note is linked through a created workflow_note' do
        let_it_be(:unauthorized_linked_note) { create(:note, project: issue.project, noteable: issue) }

        let(:note) { unauthorized_linked_note }

        before_all do
          ::Ai::DuoWorkflows::WorkflowNote.ensure_link(
            workflow: workflow, artifact: unauthorized_linked_note, link_type: :created
          )
        end

        it 'omits duo_session_id' do
          expect(subject.key?(:duo_session_id)).to be false
        end
      end
    end

    context 'when there is no current user' do
      let(:request) { double('request', current_user: nil, noteable: issue) }

      it 'omits duo_session_id for anonymous users' do
        expect(subject.key?(:duo_session_id)).to be false
      end
    end

    context 'when the note is not a system note' do
      it 'exposes the workflow id as duo_session_id' do
        expect(subject[:duo_session_id]).to eq(workflow.id)
      end

      context 'when the note has no duo_metadata' do
        let_it_be(:note_without_metadata) { create(:note, project: issue.project, noteable: issue) }

        let(:note) { note_without_metadata }

        it 'exposes duo_session_id as nil' do
          expect(subject[:duo_session_id]).to be_nil
        end

        it 'omits the key entirely rather than sending null on every note' do
          expect(subject.key?(:duo_session_id)).to be false
        end
      end

      context 'when the note is linked to a workflow through a created workflow_note' do
        let_it_be(:linked_note) { create(:note, project: issue.project, noteable: issue) }

        let(:note) { linked_note }

        before_all do
          ::Ai::DuoWorkflows::WorkflowNote.ensure_link(
            workflow: workflow, artifact: linked_note, link_type: :created
          )
        end

        it 'falls back to the linked workflow id' do
          expect(subject[:duo_session_id]).to eq(workflow.id)
        end
      end
    end

    context 'when the note is a system note' do
      let(:note) { system_note }

      it 'does not expose duo_session_id' do
        expect(subject.key?(:duo_session_id)).to be false
      end
    end

    context 'when the note is a duo_mention_started system note' do
      let_it_be(:duo_mention_note) do
        create(:system_note, project: issue.project, noteable: issue,
          system_note_metadata: create(:system_note_metadata, action: 'duo_mention_started'))
      end

      let_it_be(:duo_mention_metadata) do
        create(:note_duo_metadata, note: duo_mention_note, workflow_id: workflow.id,
          namespace_id: issue.namespace_id)
      end

      let(:note) { duo_mention_note }

      it 'exposes the workflow id as duo_session_id' do
        expect(subject[:duo_session_id]).to eq(workflow.id)
      end
    end
  end

  describe 'duo_session_status', feature_category: :duo_code_review do
    let_it_be(:workflow) { create(:duo_workflows_workflow, project: issue.project) }

    context 'when the note is a duo_mention_started system note' do
      # Use a dedicated system note so we don't conflict with the top-level
      # system_note_metadata (which already occupies the unique slot on system_note).
      let_it_be(:duo_mention_note) do
        create(:system_note, project: issue.project, noteable: issue,
          system_note_metadata: create(:system_note_metadata, action: 'duo_mention_started'))
      end

      let_it_be(:duo_note_metadata) do
        create(:note_duo_metadata, note: duo_mention_note, workflow_id: workflow.id,
          namespace_id: issue.namespace_id)
      end

      let(:note) { duo_mention_note }

      it 'exposes duo_session_status as the workflow status name (not the raw enum value)' do
        expect(subject[:duo_session_status]).to eq(workflow.status_name)
        expect(subject[:duo_session_status]).not_to eq(workflow.status)
      end
    end

    context 'when the note is a system note with a different action' do
      let(:note) { system_note }

      it 'does not expose duo_session_status' do
        expect(subject.key?(:duo_session_status)).to be false
      end
    end

    context 'when the note is not a system note' do
      it 'does not expose duo_session_status' do
        expect(subject.key?(:duo_session_status)).to be false
      end
    end
  end

  describe 'description versions', feature_category: :team_planning do
    let(:note) { system_note }

    context 'when description_diffs license is available' do
      before do
        stub_licensed_features(description_diffs: true)
      end

      it 'includes description versions attributes' do
        expect(subject[:description_version_id]).to eq(description_version.id)
        expect(subject[:description_diff_path]).to eq(description_diff_project_issue_path(issue.project, issue, description_version.id))
        expect(subject[:delete_description_version_path]).to eq(delete_description_version_project_issue_path(issue.project, issue, description_version.id))
        expect(subject[:can_delete_description_version]).to eq(true)
      end
    end

    context 'when description_diffs license is not available' do
      before do
        stub_licensed_features(description_diffs: false)
      end

      it 'does not include description versions attributes' do
        expect(subject[:description_version_id]).to be_nil
        expect(subject[:description_diff_path]).to be_nil
        expect(subject[:delete_description_version_path]).to be_nil
        expect(subject[:can_delete_description_version]).to be_nil
      end
    end
  end
end
