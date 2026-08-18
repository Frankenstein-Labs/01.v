# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::LegacyEpics::EpicIssues::DestroyService, feature_category: :portfolio_management do
  describe '#execute' do
    let_it_be(:guest) { create(:user) }
    let_it_be(:non_member) { create(:user) }
    let_it_be_with_refind(:group) { create(:group, :public, guests: guest) }
    let_it_be_with_refind(:project) do
      create(:project, :public, group: create(:group, :public), guests: guest)
    end

    let_it_be_with_reload(:epic) { create(:epic, group: group) }
    let_it_be_with_reload(:issue) { create(:issue, project: project) }
    let_it_be_with_reload(:epic_issue) { create(:epic_issue, epic: epic, issue: issue) }

    subject(:execute) { described_class.new(epic_issue, user).execute }

    shared_examples 'removes relationship with the issue' do
      it 'returns success message' do
        is_expected.to eq(message: 'Relation was removed', status: :success)
      end

      it 'creates 2 system notes' do
        expect { execute }.to change { Note.count }.from(0).to(2)
      end

      it 'creates a note for epic work item correctly' do
        execute
        note = Note.find_by(noteable_id: epic.work_item.id, noteable_type: 'Issue')

        expect(note.note).to eq("removed child item #{issue.to_reference(epic.group)}")
        expect(note.author).to eq(user)
        expect(note.project).to be_nil
        expect(note.noteable_type).to eq('Issue')
        expect(note.system_note_metadata.action).to eq('unrelate_from_child')
      end

      it 'creates a note for issue correctly' do
        execute
        note = Note.find_by(noteable_id: issue.id, noteable_type: 'Issue')

        expect(note.note).to eq("removed parent item #{epic.work_item.to_reference(issue.project)}")
        expect(note.author).to eq(user)
        expect(note.project).to eq(issue.project)
        expect(note.noteable_type).to eq('Issue')
        expect(note.system_note_metadata.action).to eq('unrelate_from_parent')
      end
    end

    context 'when epics feature is disabled' do
      let(:user) { guest }

      it 'returns an error' do
        is_expected.to eq(message: 'No Issue Link found', status: :error, http_status: 404)
      end
    end

    context 'when epics feature is enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'when user has permissions to remove associations' do
        let(:user) { guest }

        it 'removes related issue' do
          expect { execute }.to change { EpicIssue.count }.from(1).to(0)
        end

        it_behaves_like 'removes relationship with the issue'

        context 'when epic has a synced work item' do
          let_it_be_with_reload(:child_issue) { create(:issue, project: project) }
          let_it_be_with_reload(:epic) { create(:epic, :with_synced_work_item, group: group) }
          let_it_be_with_refind(:epic_issue) { create(:epic_issue, epic: epic, issue: child_issue) }
          let_it_be(:work_item_issue) { WorkItem.find(child_issue.id) }

          before do
            allow(GraphqlTriggers).to receive(:issuable_epic_updated).and_call_original
          end

          it 'removes the epic and work item link and keep epic in sync' do
            expect { execute }.to change { EpicIssue.count }.by(-1)
              .and(change { WorkItems::ParentLink.count }.by(-1))

            expect(epic.reload.updated_at).to eq(epic.work_item.updated_at)
          end

          it_behaves_like 'removes relationship with the issue' do
            let(:issue) { child_issue }
          end

          context 'when destroying work item parent link fails' do
            before do
              allow_next_instance_of(::WorkItems::ParentLinks::DestroyService) do |service|
                allow(service).to receive(:execute).and_return({ status: :error, message: 'error message' })
              end
            end

            it 'does not remove parent epic or destroy work item parent link' do
              expect { execute }.to not_change { EpicIssue.count }
                .and(not_change { WorkItems::ParentLink.count })

              expect(epic.reload.issues).to include(child_issue)
              expect(epic.work_item.reload.work_item_children).to include(work_item_issue)
            end
          end
        end
      end

      context 'when user does not have permissions to remove associations' do
        let(:user) { non_member }

        it 'does not remove relation' do
          expect { execute }.not_to change { EpicIssue.count }.from(1)
        end

        it 'returns error message' do
          is_expected.to eq(message: 'No Issue Link found', status: :error, http_status: 404)
        end
      end
    end
  end
end
