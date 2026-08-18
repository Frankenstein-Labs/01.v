# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::ParentLinks::DestroyService, feature_category: :team_planning do
  include LegacyEpicsHelper
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, reporters: user) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:work_item_epic1) { create(:work_item, :epic, namespace: group) }
    let_it_be(:work_item_epic2) { create(:work_item, :epic, namespace: group) }
    let_it_be(:work_item_issue) { create(:work_item, :issue, project: project) }
    let_it_be(:issue) { Issue.find(work_item_issue.id) }
    let_it_be_with_refind(:synced_epic1) { create(:epic, :with_synced_work_item, group: group) }
    let_it_be(:synced_epic2) { create(:epic, :with_synced_work_item, group: group) }
    let_it_be(:with_synced_epic1) { synced_epic1.work_item }
    let_it_be(:with_synced_epic2) { synced_epic2.work_item }

    let(:params) { {} }

    before do
      stub_licensed_features(epics: true, subepics: true)
    end

    subject(:destroy_link) { described_class.new(parent_link, user, params).execute }

    shared_examples 'destroys parent link' do |notes_created: 2|
      it 'only destroys parent link' do
        expect { destroy_link }.to change { WorkItems::ParentLink.count }.by(-1)
                               .and change { Note.count }.by(notes_created)
      end

      it 'returns success message' do
        is_expected.to eq(message: 'Relation was removed', status: :success)
      end
    end

    shared_examples 'does not remove relationship' do
      it 'does not remove relation', :aggregate_failures do
        expect { destroy_link }.to not_change { WorkItems::ParentLink.count }.from(1)
          .and not_change { WorkItems::ResourceLinkEvent.count }
        expect(SystemNoteService).not_to receive(:unrelate_work_item)
      end

      it 'returns error message' do
        is_expected.to eq(message: 'No Work Item Link found', status: :error, http_status: 404)
      end
    end

    context "when parent nor child don't have a synced epic" do
      let_it_be_with_refind(:parent_link) do
        create(:parent_link, work_item: work_item_epic1, work_item_parent: work_item_epic2)
      end

      it_behaves_like 'destroys parent link'

      context 'when epic work item type' do
        context 'when subepics are not available' do
          before do
            stub_licensed_features(epics: true, subepics: false)
          end

          it_behaves_like 'does not remove relationship'
        end
      end
    end

    context "when only parent work item has a synced epic" do
      let_it_be_with_refind(:parent_link) do
        create(:parent_link, work_item: work_item_epic1, work_item_parent: with_synced_epic1)
      end

      context 'when synced_work_item param is true' do
        let(:params) { { synced_work_item: true } }

        it_behaves_like 'destroys parent link', notes_created: 0
      end

      context 'when synced_work_item param is false' do
        let(:params) { { synced_work_item: false } }

        it_behaves_like 'destroys parent link'

        context 'with existing epic issue link' do
          let_it_be_with_refind(:parent_link) do
            create(:parent_link, :with_epic_issue, work_item: work_item_issue, work_item_parent: with_synced_epic1)
          end

          it 'removes parent link and epic issue link', :aggregate_failures do
            expect { destroy_link }.to change { WorkItems::ParentLink.count }.by(-1)
                                   .and change { EpicIssue.count }.by(-1)
                                   .and change { WorkItems::ResourceLinkEvent.count }.by(1)
                                   .and change { Note.count }.by(2)

            expect(work_item_issue.reload.notes.last.note)
              .to eq("removed parent item #{with_synced_epic1.to_reference(full: true)}")
            expect(with_synced_epic1.reload.notes.last.note)
              .to eq("removed child item #{work_item_issue.to_reference(full: true)}")
          end

          context 'when destroying parent link fails' do
            before do
              allow(parent_link).to receive(:destroy!).and_raise(StandardError, 'Some error')
            end

            it 'does not destroy parent link or epic issue link' do
              expect { destroy_link }.to raise_error(StandardError)
                                           .and not_change { WorkItems::ParentLink.count }
                                           .and not_change { EpicIssue.count }
                                           .and not_change { WorkItems::ResourceLinkEvent.count }
                                           .and not_change { Note.count }
            end
          end
        end
      end
    end

    context 'when only child work item has a synced epic' do
      let_it_be_with_refind(:parent_link) do
        create(:parent_link, work_item: with_synced_epic1, work_item_parent: work_item_epic1)
      end

      context 'when synced_work_item param is true' do
        let(:params) { { synced_work_item: true } }

        it_behaves_like 'destroys parent link', notes_created: 0
      end

      context 'when synced_work_item param is false' do
        let(:params) { { synced_work_item: false } }

        it_behaves_like 'destroys parent link'
      end
    end

    context 'when parent and child have a synced epic' do
      let_it_be_with_refind(:parent_link) do
        create(:parent_link, work_item: with_synced_epic1, work_item_parent: with_synced_epic2)
      end

      context 'when synced_work_item param is true' do
        let(:params) { { synced_work_item: true } }

        it_behaves_like 'destroys parent link', notes_created: 0
      end

      context 'when synced_work_item param is false' do
        let(:params) { { synced_work_item: false } }

        it_behaves_like 'destroys parent link'

        context 'without group level work items license' do
          before do
            stub_licensed_features(epics: false, subepics: true)
          end

          it_behaves_like 'does not remove relationship'
        end

        context 'with existing legacy epic parent' do
          before do
            assign_epic_parent(synced_epic1, synced_epic2)
          end

          it 'destroys parent link and remove legacy parent' do
            expect { destroy_link }.to change { WorkItems::ParentLink.count }.by(-1)
                                   .and change { synced_epic2.reload.children.count }.by(-1)
                                   .and change { WorkItems::ResourceLinkEvent.count }.by(1)
                                   .and change { Note.count }.by(2)

            expect(with_synced_epic1.reload.notes.last.note)
              .to eq("removed parent item #{with_synced_epic2.to_reference}")
            expect(with_synced_epic2.reload.notes.last.note)
              .to eq("removed child item #{with_synced_epic1.to_reference}")
          end
        end

        context 'when destroying parent link fails' do
          before do
            allow(parent_link).to receive(:destroy!).and_raise(StandardError, 'Some error')
          end

          it 'does not destroy parent link or epic issue link' do
            assign_epic_parent(synced_epic1, synced_epic2)

            expect { destroy_link }.to raise_error(StandardError)
                                   .and not_change { WorkItems::ParentLink.count }
                                   .and not_change { synced_epic2.reload.children.count }
                                   .and not_change { WorkItems::ResourceLinkEvent.count }
                                   .and not_change { Note.count }
          end
        end
      end
    end
  end
end
