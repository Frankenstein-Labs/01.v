# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::LegacyEpics::UpdateService, feature_category: :team_planning do
  let_it_be(:ancestor_group) { create(:group, :internal) }
  let_it_be(:group, freeze: false) { create(:group, :internal, parent: ancestor_group) }
  let_it_be(:group_without_access) { create(:group, :private) }
  let_it_be(:user) { create(:user, owner_of: group) }
  let_it_be(:other_user) { create(:user) }
  let_it_be(:author) { create(:user) }
  let_it_be(:label0, freeze: false) { create(:group_label, group: group) }
  let_it_be(:label1, freeze: false) { create(:group_label, group: group) }
  let_it_be(:label2, freeze: false) { create(:group_label, group: group) }
  let_it_be(:parent_epic) { create(:epic, :with_synced_work_item, group: group) }
  let!(:epic) { create(:epic, :with_synced_work_item, group: group, labels: [label1]) }

  let(:edited_date) { '2025-01-12T01:00:00Z' }
  let(:closed_date) { '2025-01-13T01:00:00Z' }
  let(:start_date) { Date.new(2025, 1, 1) }
  let(:due_date) { Date.new(2025, 1, 31) }

  let(:params) do
    {
      title: 'updated epic title',
      description: 'updated epic description',
      parent: parent_epic,
      confidential: true,
      add_label_ids: [label2.id],
      label_ids: [label0.id],
      remove_label_ids: [label1.id],
      updated_by_id: user.id,
      last_edited_by_id: other_user.id,
      closed_by_id: other_user.id,
      closed_at: closed_date,
      state_id: 2,
      color: '#c91c00',
      start_date_is_fixed: true,
      start_date_fixed: start_date,
      due_date_is_fixed: true,
      due_date_fixed: due_date
    }
  end

  subject(:execute) { described_class.new(group: group, current_user: user, params: params).execute(epic) }

  before do
    stub_licensed_features(epics: true, subepics: true, epic_colors: true)
  end

  shared_examples 'success' do
    it 'updates the legacy epic and work item epic' do
      expect { execute }.to not_change { Epic.count }.and not_change { WorkItem.count }

      updated_epic = execute

      expect(updated_epic.title).to eq(params[:title])
      expect(updated_epic.closed_at).to eq(params[:closed_at])
      expect(updated_epic.errors.empty?).to be(true)
      expect(updated_epic.description).to eq('updated epic description')
      expect(updated_epic.state_id).to eq(Epic.available_states['closed'])
      expect(updated_epic.labels).to contain_exactly(label0, label2)
      expect(updated_epic.confidential).to be_truthy
      expect(updated_epic.color.to_s).to eq('#c91c00')
      expect(updated_epic.start_date_is_fixed).to be_truthy
      expect(updated_epic.due_date_is_fixed).to be_truthy
      expect(updated_epic.due_date_fixed).to eq(due_date)
      expect(updated_epic.start_date_fixed).to eq(start_date)

      diff = Gitlab::EpicWorkItemSync::Diff.new(updated_epic, updated_epic.work_item, strict_equal: true)
      expect(diff.attributes).to be_empty
    end

    context 'when setting a parent' do
      shared_examples 'updates epic with a parent' do
        it 'sets the parent and creates a new work item parent link' do
          expect { execute }.to change { WorkItems::ParentLink.count }.by(1)

          updated_epic = execute
          expect(updated_epic.errors.empty?).to be(true)
          expect(updated_epic.relative_position).not_to be_nil
          expect(updated_epic.parent).to eq(parent_epic)
          expect(updated_epic.work_item_parent_link).to eq(updated_epic.work_item.parent_link)
          expect(updated_epic.work_item.work_item_parent).to eq(parent_epic.work_item)
        end
      end

      shared_examples 'does not update epic' do
        it 'returns an epic record with errors' do
          updated_epic = execute
          expect { updated_epic }.to not_change { WorkItems::ParentLink.count }

          expect(updated_epic.errors.full_messages).to contain_exactly(parent_not_found_error)
        end
      end

      context 'when parent param is present' do
        it_behaves_like 'updates epic with a parent'
      end

      context 'when parent_id param is present' do
        let(:params) { super().merge(parent_id: parent_epic.id) }

        it_behaves_like 'updates epic with a parent'
      end

      context 'when subepics are not supported for the group' do
        let(:params) { super().merge(parent: parent_epic) }

        before do
          stub_licensed_features(epics: true, subepics: false)
        end

        it_behaves_like 'does not update epic'
      end

      context 'when user has no access to the parent epic' do
        let_it_be(:no_access_parent) { create(:epic, :with_synced_work_item, group: group_without_access) }

        let(:params) { super().merge(parent: no_access_parent) }

        it_behaves_like 'does not update epic'
      end
    end
  end

  describe '#execute' do
    it_behaves_like 'success' do
      let(:parent_not_found_error) do
        'No matching epic found. Make sure that you are adding a valid epic URL.'
      end
    end

    it 'calls the WorkItems::UpdateService with the correct params' do
      allow(::WorkItems::UpdateService).to receive(:new).and_call_original

      expect(::WorkItems::UpdateService).to receive(:new).with(
        a_hash_including(
          container: group,
          current_user: user,
          perform_spam_check: true,
          params: {
            title: "updated epic title",
            confidential: true,
            updated_by_id: user.id,
            last_edited_by_id: other_user.id,
            closed_by_id: other_user.id,
            closed_at: closed_date,
            state_id: 2,
            work_item_type: build(:work_item_system_defined_type, :epic)
          },
          widget_params: a_hash_including(
            description_widget: { description: "updated epic description" },
            color_widget: { color: '#c91c00' },
            hierarchy_widget: { parent: parent_epic.work_item },
            start_and_due_date_widget: { is_fixed: true, due_date: due_date, start_date: start_date },
            labels_widget: { add_label_ids: [label2.id], label_ids: [label0.id], remove_label_ids: [label1.id] }
          )
        )
      ).and_call_original

      execute
    end

    it 'uses WorkItems::UpdateService and transforms the result' do
      expect(::WorkItems::UpdateService).to receive(:new).and_call_original

      execute
    end

    context 'when WorkItems::UpdateService returns errors' do
      let(:error_messages) { ['work item error 1', 'work item error 2'] }

      before do
        allow_next_instance_of(::WorkItems::UpdateService) do |instance|
          allow(instance).to receive(:execute)
            .and_return({ status: :error, message: error_messages, work_item: epic.work_item })
        end
      end

      it 'transforms and returns epic with errors from the work item service' do
        updated_epic = execute
        expect(updated_epic.errors.full_messages).to contain_exactly('work item error 1', 'work item error 2')
      end
    end

    context 'when response includes errors' do
      context 'with epic validation errors' do
        let_it_be(:confidential_parent) { create(:epic, :with_synced_work_item, :confidential, group: group) }
        let(:params) { super().merge(parent: confidential_parent, confidential: false) }
        let(:error_message) do
          "#{confidential_parent.work_item.to_reference} cannot be added: cannot assign " \
            "a non-confidential epic to a confidential parent. " \
            "Make the epic confidential and try again."
        end

        it 'returns epic with errors' do
          updated_epic = execute
          expect(updated_epic.errors.full_messages).to include(error_message)
        end
      end

      context 'when work item update returns errors' do
        let(:error_messages) { ['error message 1', 'error message 2'] }

        before do
          allow_next_instance_of(::WorkItems::UpdateService) do |instance|
            allow(instance).to receive(:execute)
              .and_return({ status: :error, message: error_messages, work_item: epic.work_item })
          end
        end

        it 'returns epic with errors from the service' do
          updated_epic = execute
          expect(updated_epic.errors.full_messages).to contain_exactly('error message 1', 'error message 2')
        end
      end

      context 'when work item update returns no work item' do
        before do
          allow_next_instance_of(::WorkItems::UpdateService) do |instance|
            allow(instance).to receive(:execute)
              .and_return({ status: :error, message: ['error message'], work_item: nil })
          end
        end

        it 'returns a new epic with errors' do
          updated_epic = execute
          expect(updated_epic).to be_a_new(Epic)
          expect(updated_epic.errors.full_messages).to contain_exactly('error message')
        end
      end
    end

    context 'when description param has quick action' do
      let(:epic_without_parent) { create(:epic, :with_synced_work_item, group: group) }

      context 'for /set_parent' do
        shared_examples 'assigning a valid parent epic' do
          let_it_be(:description) { "/set_parent #{parent_epic.to_reference(group, full: true)}" }
          let_it_be(:params, freeze: false) { { title: 'Updated epic with parent', description: description } }

          it 'sets parent epic' do
            result = described_class.new(group: group, current_user: user, params: params).execute(epic_without_parent)
            expect(result.reset.parent).to eq(parent_epic)
          end
        end

        context 'when parent is in the same group' do
          it_behaves_like 'assigning a valid parent epic'
        end

        context 'when parent is in an ancestor group' do
          let(:new_group) { ancestor_group }

          before_all do
            ancestor_group.add_reporter(user)
          end

          it_behaves_like 'assigning a valid parent epic'
        end

        context 'when parent is in a descendant group' do
          let_it_be(:descendant_group) { create(:group, :private, parent: group) }
          let(:new_group) { descendant_group }

          before_all do
            descendant_group.add_reporter(user)
          end

          it_behaves_like 'assigning a valid parent epic'
        end

        context 'when parent is in a different group hierarchy' do
          let_it_be(:other_group) { create(:group, :private) }
          let(:new_group) { other_group }

          context 'when user has access to the group' do
            before_all do
              other_group.add_reporter(user)
            end

            it_behaves_like 'assigning a valid parent epic'
          end

          context 'when user does not have access to the group' do
            let_it_be(:parent) { create(:work_item, :epic_with_legacy_epic, namespace: other_group) }
            let_it_be(:description) { "/set_parent #{parent.to_reference(other_group, full: true)}" }
            let_it_be(:params, freeze: false) { { title: 'Updated epic with parent', description: description } }

            it 'does not set parent epic but still updates the epic' do
              expect do
                described_class.new(group: group, current_user: user, params: params).execute(epic_without_parent)
              end
                .to not_change { WorkItems::ParentLink.count }

              result = described_class.new(group: group, current_user: user,
                params: params).execute(epic_without_parent)
              expect(result.reload.parent).to be_nil
              expect(result.title).to eq('Updated epic with parent')
            end
          end
        end
      end

      context 'for /add_child' do
        let_it_be(:child_epic) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
        let_it_be(:description) { "/add_child #{child_epic.to_reference}" }
        let_it_be(:params, freeze: false) { { title: 'Updated epic with child', description: description } }

        it 'sets a child epic' do
          expect { described_class.new(group: group, current_user: user, params: params).execute(epic_without_parent) }
            .to change { WorkItems::ParentLink.count }.by(1)

          result = described_class.new(group: group, current_user: user, params: params).execute(epic_without_parent)
          expect(result.reload.children).to include(child_epic.sync_object)
        end

        context 'when child epic cannot be assigned' do
          let(:other_group) { create(:group, :private) }
          let(:child_epic) { create(:work_item, :epic_with_legacy_epic, namespace: other_group) }

          it 'does not set child epic' do
            expect do
              described_class.new(group: group, current_user: user, params: params).execute(epic_without_parent)
            end
              .to not_change { WorkItems::ParentLink.count }

            result = described_class.new(group: group, current_user: user, params: params).execute(epic_without_parent)
            expect(result.reload.children).to be_empty
          end
        end
      end
    end

    context 'when updating state' do
      context 'when closing' do
        let(:params) { { state_id: Epic.available_states['closed'] } }

        it 'updates the epic state' do
          expect(epic.state_id).to eq(Epic.available_states['opened'])

          updated_epic = execute
          expect(updated_epic.state_id).to eq(Epic.available_states['closed'])
        end
      end

      context 'when opening' do
        let_it_be(:closed_epic, freeze: false) { create(:epic, :with_synced_work_item, :closed, group: group) }
        let(:params) { { state_id: Epic.available_states['opened'] } }

        it 'updates the epic state' do
          result = described_class.new(group: group, current_user: user, params: params).execute(closed_epic)
          expect(result.state_id).to eq(Epic.available_states['opened'])
        end
      end
    end

    context 'when updating labels' do
      it 'correctly handles label changes' do
        expect(epic.labels).to contain_exactly(label1)

        updated_epic = execute
        expect(updated_epic.labels).to contain_exactly(label0, label2)
      end

      context 'when only adding labels' do
        let(:params) { { add_label_ids: [label2.id] } }

        it 'adds the specified labels' do
          updated_epic = execute
          expect(updated_epic.labels).to contain_exactly(label1, label2)
        end
      end

      context 'when only removing labels' do
        let(:params) { { remove_label_ids: [label1.id] } }

        it 'removes the specified labels' do
          updated_epic = execute
          expect(updated_epic.labels).to be_empty
        end
      end
    end
  end
end
