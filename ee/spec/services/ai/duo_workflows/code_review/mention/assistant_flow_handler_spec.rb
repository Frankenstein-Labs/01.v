# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CodeReview::Mention::AssistantFlowHandler, feature_category: :duo_code_review do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be(:author) { create(:user) }
  let_it_be(:note) do
    create(:diff_note_on_merge_request, noteable: merge_request, project: project, author: author)
  end

  subject(:handler) { described_class.new(note) }

  describe '#execute' do
    let(:code_review_flow) do
      instance_double(::Ai::Catalog::FoundationalFlow, foundational_flow_reference: 'code_review/v1')
    end

    let(:catalog_item) { instance_double(::Ai::Catalog::Item, id: 1) }
    let(:service_account) { build_stubbed(:user, :service_account) }
    let(:sa_result) { ServiceResponse.success(payload: { service_account: service_account }) }
    let(:adapter_double) { instance_double(::Ai::Messaging::Adapters::GitlabDuoNote, trigger: nil) }

    before do
      allow(::Ai::Catalog::FoundationalFlow).to receive(:code_review).and_return(code_review_flow)
      allow(code_review_flow).to receive(:catalog_item).and_return(catalog_item)
      allow_next_instance_of(::Ai::Catalog::ItemConsumers::ResolveServiceAccountService) do |svc|
        allow(svc).to receive(:execute).and_return(sa_result)
      end
      allow(::Ai::Messaging::Adapters::GitlabDuoNote).to receive(:for_note).and_return(adapter_double)
      allow(note.project).to receive_messages(
        duo_foundational_flows_enabled: true,
        enabled_flow_catalog_item_ids: [catalog_item.id]
      )
    end

    it 'builds the adapter from the note authored as the Duo code-review bot' do
      expect(::Ai::Messaging::Adapters::GitlabDuoNote).to receive(:for_note).with(
        note,
        note_author_id: ::Users::Internal.in_organization(note.project.organization_id).duo_code_review_bot.id
      ).and_return(adapter_double)

      handler.execute
    end

    it 'triggers the adapter with the correct bundle attributes' do
      expect(adapter_double).to receive(:trigger).with(
        an_object_having_attributes(
          current_user: author,
          service_account: service_account,
          flow_reference: 'code_review/v1',
          flow_config_id: 'gitlab_duo_mention_assistant',
          flow_config_schema_version: 'v1',
          project: project,
          resource: merge_request,
          source_branch: merge_request.source_branch
        )
      )

      handler.execute
    end

    context 'when the noteable is not a merge request' do
      let_it_be(:issue) { create(:issue, project: project) }
      let_it_be(:note) { create(:note_on_issue, noteable: issue, project: project, author: author) }

      it 'passes a nil source_branch to the trigger bundle' do
        expect(adapter_double).to receive(:trigger).with(
          an_object_having_attributes(
            resource: issue,
            source_branch: nil
          )
        )

        handler.execute
      end
    end

    describe 'goal content' do
      it 'includes gitlab_context and conversation blocks' do
        expect(adapter_double).to receive(:trigger).with(
          an_object_having_attributes(goal: include('<gitlab_context>').and(include('<conversation>')))
        )

        handler.execute
      end

      it 'includes MR source and target branch in gitlab_context' do
        expect(adapter_double).to receive(:trigger).with(
          an_object_having_attributes(
            goal: include("Source branch: #{merge_request.source_branch}")
              .and(include("Target branch: #{merge_request.target_branch}"))
          )
        )

        handler.execute
      end

      it 'includes the diff file path in gitlab_context for diff notes' do
        expect(adapter_double).to receive(:trigger).with(
          an_object_having_attributes(goal: include("File: #{note.latest_diff_file_path}"))
        )

        handler.execute
      end

      it 'labels user messages with @username in the conversation' do
        expect(adapter_double).to receive(:trigger).with(
          an_object_having_attributes(goal: include("author=\"@#{author.username}\""))
        )

        handler.execute
      end

      context 'when a bot reply exists in the discussion' do
        before do
          duo_bot = ::Users::Internal.in_organization(project.organization_id).duo_code_review_bot
          bot_note = build_stubbed(:note, author: duo_bot, note: 'Bot reply')
          allow(note).to receive_messages(
            discussion: instance_double(Discussion, notes: [note, bot_note]),
            raw_truncated_diff_lines: ''
          )
        end

        it 'labels the bot message with GitLabDuo in the conversation' do
          expect(adapter_double).to receive(:trigger).with(
            an_object_having_attributes(goal: include('author="GitLabDuo"'))
          )

          handler.execute
        end
      end
    end

    context 'when catalog_item is nil' do
      before do
        allow(code_review_flow).to receive(:catalog_item).and_return(nil)
      end

      it 'does not trigger the adapter' do
        expect(adapter_double).not_to receive(:trigger)

        handler.execute
      end
    end

    context 'when the foundational flow is not enabled for the project' do
      before do
        allow(note.project).to receive_messages(
          duo_foundational_flows_enabled: false,
          enabled_flow_catalog_item_ids: []
        )
      end

      it 'posts a flow-not-enabled error note and does not trigger the adapter' do
        expect(adapter_double).not_to receive(:trigger)
        expect { handler.execute }.to change { Note.count }.by(1)
        expect(Note.order(id: :desc).first.note).to include('Code Review Flow is not enabled')
      end
    end

    context 'when SA resolution fails' do
      let(:sa_result) { ServiceResponse.error(message: 'SA not configured') }

      it 'posts a missing service account error note and does not trigger the adapter' do
        expect(adapter_double).not_to receive(:trigger)
        expect { handler.execute }.to change { Note.count }.by(1)
        expect(Note.order(id: :desc).first.note).to include('Code Review Flow is enabled')
      end
    end
  end
end
