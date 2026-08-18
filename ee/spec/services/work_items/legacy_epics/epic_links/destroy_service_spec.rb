# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::LegacyEpics::EpicLinks::DestroyService, feature_category: :portfolio_management do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:child_epic_group) { create(:group, :private) }
    let_it_be(:parent_epic_group) { create(:group, :private) }
    let_it_be_with_reload(:parent_epic) { create(:epic, group: parent_epic_group) }
    let_it_be_with_reload(:child_epic) { create(:epic, parent: parent_epic, group: child_epic_group) }

    shared_examples 'system notes created' do
      it 'creates system notes' do
        expect { destroy_link }.to change { Note.system.count }.from(0).to(2)
      end
    end

    shared_examples 'returns success' do
      it 'removes epic relationship' do
        expect { destroy_link }.to change { parent_epic.reload.children.count }.by(-1)

        expect(parent_epic.reload.children).not_to include(child_epic)
      end

      it 'returns success status' do
        expect(destroy_link).to eq(message: 'Relation was removed', status: :success)
      end
    end

    shared_examples 'returns not found error' do
      it 'returns an error' do
        expect(destroy_link).to eq(message: 'No Epic found for given params', status: :error, http_status: 404)
      end

      it 'no relationship is created' do
        expect { destroy_link }.not_to change { parent_epic.children.count }
      end

      it 'does not create system notes' do
        expect { destroy_link }.not_to change { Note.system.count }
      end
    end

    def remove_epic_relation(child_epic)
      described_class.new(child_epic, user).execute
    end

    context 'when epics feature is disabled' do
      before do
        stub_licensed_features(epics: false, subepics: false)
      end

      subject(:destroy_link) { remove_epic_relation(child_epic) }

      include_examples 'returns not found error'
    end

    context 'when epics feature is enabled' do
      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      context 'when the user has no access to parent epic' do
        subject(:destroy_link) { remove_epic_relation(child_epic) }

        before_all do
          child_epic_group.add_guest(user)
        end

        include_examples 'returns not found error'
      end

      context 'when the user has no access to child epic' do
        subject(:destroy_link) { remove_epic_relation(child_epic) }

        before_all do
          parent_epic_group.add_guest(user)
        end

        include_examples 'returns not found error'
      end

      context 'when user has permissions to remove epic relation' do
        before_all do
          child_epic_group.add_guest(user)
          parent_epic_group.add_guest(user)
        end

        context 'when the child epic is nil' do
          subject(:destroy_link) { remove_epic_relation(nil) }

          include_examples 'returns not found error'
        end

        context 'when a correct reference is given' do
          subject(:destroy_link) { remove_epic_relation(child_epic) }

          include_examples 'returns success'
          include_examples 'system notes created'
        end

        context 'when epic has no parent' do
          subject(:destroy_link) { remove_epic_relation(parent_epic) }

          include_examples 'returns not found error'
        end

        context 'for work item data' do
          it 'removes epic relationship and destroy work item parent link' do
            expect { remove_epic_relation(child_epic) }.to change { parent_epic.reload.children.count }.by(-1)
              .and(change { WorkItems::ParentLink.count }.by(-1))
          end

          it 'create resource event for the work item' do
            expect(WorkItems::ResourceLinkEvent).to receive(:create)

            remove_epic_relation(child_epic)
          end

          it 'creates system notes only for the epics' do
            expect { remove_epic_relation(child_epic) }.to change { Note.system.count }.by(2)

            expect(parent_epic.notes.last.note).to eq(
              "removed child item #{child_epic.work_item.to_reference(full: true)}"
            )

            expect(child_epic.notes.last.note).to eq(
              "removed parent item #{parent_epic.work_item.to_reference(full: true)}"
            )
          end
        end
      end
    end
  end
end
