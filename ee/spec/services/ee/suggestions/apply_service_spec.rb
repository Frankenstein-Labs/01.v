# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Suggestions::ApplyService, feature_category: :continuous_integration do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, :commit_email) }

  let(:project) { create(:project, :repository, group: group) }
  let(:merge_request) do
    create(:merge_request, source_project: project, target_project: project, source_branch: 'master')
  end

  def create_suggestion(author:, new_line: 9)
    position = Gitlab::Diff::Position.new(
      old_path: "files/ruby/popen.rb",
      new_path: "files/ruby/popen.rb",
      old_line: nil,
      new_line: new_line,
      diff_refs: merge_request.diff_refs
    )

    diff_note = create(:diff_note_on_merge_request,
      noteable: merge_request, position: position, project: project, author: author)

    create(:suggestion, :content_from_repo, note: diff_note)
  end

  before do
    project.add_maintainer(user)
  end

  describe '#execute' do
    let_it_be(:service_account) { create(:user, :ai_service_account, provisioned_by_group: group) }

    context 'with a Fix Pipeline service account' do
      let_it_be(:catalog_item) do
        create(:ai_catalog_item, :with_foundational_flow_reference, organization: group.organization)
      end

      let_it_be(:item_consumer) do
        create(:ai_catalog_item_consumer, :parent_item_consumer,
          item: catalog_item, group: group, service_account: service_account)
      end

      it 'tracks fix_pipeline_suggestion_applied with correct properties' do
        suggestion = create_suggestion(author: service_account)

        expect { described_class.new(user, suggestion).execute }
          .to trigger_internal_events('fix_pipeline_suggestion_applied').with(
            category: 'InternalEventTracking',
            user: user,
            project: project,
            additional_properties: {
              label: merge_request.id.to_s,
              property: suggestion.id.to_s,
              value: suggestion.note_id
            }
          )
      end

      it 'does not track when the apply fails' do
        suggestion = create_suggestion(author: service_account)

        allow_next_instance_of(::Files::MultiService) do |service|
          allow(service).to receive(:execute).and_return(status: :error, message: 'apply failed')
        end

        expect { described_class.new(user, suggestion).execute }
          .not_to trigger_internal_events('fix_pipeline_suggestion_applied')
      end

      it 'only tracks Fix Pipeline suggestions in a batch apply' do
        fix_pipeline_suggestion = create_suggestion(author: service_account, new_line: 9)
        human_suggestion = create_suggestion(author: user, new_line: 15)

        expect { described_class.new(user, fix_pipeline_suggestion, human_suggestion).execute }
          .to trigger_internal_events('fix_pipeline_suggestion_applied').with(
            category: 'InternalEventTracking',
            user: user,
            project: project,
            additional_properties: {
              label: merge_request.id.to_s,
              property: fix_pipeline_suggestion.id.to_s,
              value: fix_pipeline_suggestion.note_id
            }
          ).once
      end

      context 'when the merge request is from a fork' do
        let_it_be(:target_project) { create(:project, :repository, group: group) }

        it 'tracks with target_project, not source_project' do
          suggestion = create_suggestion(author: service_account)
          allow(suggestion).to receive(:target_project).and_return(target_project)
          allow(Gitlab::InternalEvents).to receive(:track_event).and_call_original

          described_class.new(user, suggestion).execute

          expect(Gitlab::InternalEvents).to have_received(:track_event).with(
            'fix_pipeline_suggestion_applied',
            hash_including(project: target_project)
          )
        end
      end
    end

    context 'when suggestion is from a regular user' do
      it 'does not track fix_pipeline_suggestion_applied' do
        suggestion = create_suggestion(author: user)

        expect { described_class.new(user, suggestion).execute }
          .not_to trigger_internal_events('fix_pipeline_suggestion_applied')
      end
    end

    context 'when suggestion is from a service account for a different flow' do
      let_it_be(:other_catalog_item) do
        create(:ai_catalog_flow, :public,
          foundational_flow_reference: "code_review/v1", organization: group.organization)
      end

      let_it_be(:item_consumer) do
        create(:ai_catalog_item_consumer, :parent_item_consumer,
          item: other_catalog_item, group: group, service_account: service_account)
      end

      it 'does not track fix_pipeline_suggestion_applied' do
        suggestion = create_suggestion(author: service_account)

        expect { described_class.new(user, suggestion).execute }
          .not_to trigger_internal_events('fix_pipeline_suggestion_applied')
      end
    end
  end
end
