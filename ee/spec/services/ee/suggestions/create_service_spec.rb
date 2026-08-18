# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Suggestions::CreateService, feature_category: :continuous_integration do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be(:user) { create(:user) }

  let(:position) do
    Gitlab::Diff::Position.new(
      old_path: "files/ruby/popen.rb",
      new_path: "files/ruby/popen.rb",
      old_line: nil,
      new_line: 14,
      diff_refs: merge_request.diff_refs
    )
  end

  let(:markdown) do
    <<~MARKDOWN
      ```suggestion
        foo
      ```
    MARKDOWN
  end

  def create_note(author:)
    create(:diff_note_on_merge_request,
      project: project, noteable: merge_request, position: position, note: markdown, author: author)
  end

  subject(:service) { described_class.new(note) }

  describe '#execute' do
    let_it_be(:service_account) { create(:user, :ai_service_account, provisioned_by_group: group) }

    context 'when note author is a Fix Pipeline service account' do
      let_it_be(:catalog_item) do
        create(:ai_catalog_item, :with_foundational_flow_reference, organization: group.organization)
      end

      let_it_be(:item_consumer) do
        create(:ai_catalog_item_consumer, :parent_item_consumer,
          item: catalog_item, group: group, service_account: service_account)
      end

      let(:note) { create_note(author: service_account) }

      it 'tracks fix_pipeline_suggestion_posted with correct properties' do
        allow(Gitlab::InternalEvents).to receive(:track_event).and_call_original

        service.execute

        suggestion = note.suggestions.first

        expect(Gitlab::InternalEvents).to have_received(:track_event).with(
          'fix_pipeline_suggestion_posted',
          user: service_account,
          project: project,
          additional_properties: {
            label: merge_request.id.to_s,
            property: suggestion.id.to_s,
            value: note.id
          }
        )
      end

      context 'when the merge request is from a fork' do
        let_it_be(:target_project) { create(:project, :repository, group: group) }

        it 'tracks with target_project, not source_project' do
          allow(note.noteable).to receive(:target_project).and_return(target_project)
          allow(Gitlab::InternalEvents).to receive(:track_event).and_call_original

          service.execute

          expect(Gitlab::InternalEvents).to have_received(:track_event).with(
            'fix_pipeline_suggestion_posted',
            hash_including(project: target_project)
          )
        end
      end
    end

    context 'when note author is a regular user' do
      let(:note) { create_note(author: user) }

      it 'does not track fix_pipeline_suggestion_posted' do
        expect { service.execute }
          .not_to trigger_internal_events('fix_pipeline_suggestion_posted')
      end
    end

    context 'when note author is a service account for a different flow' do
      let_it_be(:other_catalog_item) do
        create(:ai_catalog_flow, :public,
          foundational_flow_reference: "code_review/v1", organization: group.organization)
      end

      let_it_be(:item_consumer) do
        create(:ai_catalog_item_consumer, :parent_item_consumer,
          item: other_catalog_item, group: group, service_account: service_account)
      end

      let(:note) { create_note(author: service_account) }

      it 'does not track fix_pipeline_suggestion_posted' do
        expect { service.execute }
          .not_to trigger_internal_events('fix_pipeline_suggestion_posted')
      end
    end
  end
end
