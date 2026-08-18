# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::LegacyEpics::RelatedEpicLinks::DestroyService, feature_category: :team_planning do
  let(:epic) { source_epic }

  let_it_be(:group) { create(:group, :public) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be(:non_member_user) { create(:user) }
  let_it_be(:source_epic) { create(:epic, group: group) }
  let_it_be(:target_epic) { create(:epic, group: group) }
  let(:source_work_item) { source_epic.work_item }
  let(:target_work_item) { target_epic.work_item }
  let(:current_user) { user }

  subject(:execute) { described_class.new(related_epic_link, epic, current_user).execute }

  before do
    stub_licensed_features(epics: true, related_epics: true)
  end

  shared_examples 'success' do
    it 'destroys the related epic link and the work item link' do
      expect { execute }
        .to change { Epic::RelatedEpicLink.count }.by(-1)
        .and change { WorkItems::RelatedWorkItemLink.count }.by(-1)

      expect(execute[:status]).to eq(:success)
      expect(execute[:message]).to eq('Relation was removed')

      expect(source_epic.reload.updated_at).to eq(source_work_item.reload.updated_at)
      expect(target_epic.updated_at).to eq(target_work_item.updated_at)

      expect(source_epic.work_item.notes.last.note).to eq("removed the relation with #{target_work_item.to_reference}")
      expect(target_epic.work_item.notes.last.note).to eq("removed the relation with #{source_work_item.to_reference}")
    end
  end

  shared_examples 'error' do
    before do
      stub_licensed_features(epics: true, related_epics: false)
    end

    it 'does not destroy related epic link or work item' do
      expect { execute }
        .to not_change { Epic::RelatedEpicLink.count }
        .and not_change { WorkItems::RelatedWorkItemLink.count }

      expect(execute[:status]).to eq(:error)
      expect(execute[:http_status]).to eq(:not_found)
      expect(execute[:message]).to eq("No Related Epic Link found")
    end
  end

  describe '#execute' do
    let_it_be(:related_epic_link) do
      create(:related_epic_link, source: source_epic, target: target_epic)
    end

    context 'when it is a public group and user is not a member' do
      let(:current_user) { non_member_user }

      it 'does not remove the related links' do
        expect { execute }
          .to not_change { Epic::RelatedEpicLink.count }
          .and not_change { WorkItems::RelatedWorkItemLink.count }
      end
    end

    context 'when related epic link has a work item link associated' do
      context 'when epic is source' do
        it_behaves_like 'success'
        it_behaves_like 'error'

        it 'calls the WorkItems::RelatedWorkItemLinks::DestroyService with the correct params' do
          allow(WorkItems::RelatedWorkItemLinks::DestroyService).to receive(:new).and_call_original
          expect(WorkItems::RelatedWorkItemLinks::DestroyService).to receive(:new)
            .with(epic.work_item, user, { item_ids: [target_epic.issue_id] }).and_call_original

          execute
        end
      end

      context 'when epic is target' do
        let(:epic) { target_epic }

        it_behaves_like 'success'
        it_behaves_like 'error'

        it 'calls the WorkItems::RelatedWorkItemLinks::DestroyService with the correct params' do
          allow(WorkItems::RelatedWorkItemLinks::DestroyService).to receive(:new).and_call_original
          expect(WorkItems::RelatedWorkItemLinks::DestroyService).to receive(:new)
            .with(epic.work_item, user, { item_ids: [source_epic.issue_id] }).and_call_original

          execute
        end
      end
    end
  end
end
