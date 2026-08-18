# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::LegacyEpics::CreateService, feature_category: :team_planning do
  let_it_be(:ancestor_group) { create(:group, :internal) }
  let_it_be(:group, freeze: false) { create(:group, :internal, parent: ancestor_group) }
  let_it_be(:group_without_access) { create(:group, :private) }
  let_it_be(:user) { create(:user, owner_of: group) }
  let_it_be(:other_user) { create(:user) }
  let_it_be(:author) { create(:user) }
  let_it_be(:label0) { create(:group_label, group: group) }
  let_it_be(:label1) { create(:group_label, group: group) }
  let_it_be(:label2) { create(:group_label, group: group) }
  let_it_be(:parent_epic) { create(:epic, :with_synced_work_item, group: group) }

  let(:created_date) { '2025-01-10T01:00:00Z' }
  let(:edited_date) { '2025-01-12T01:00:00Z' }
  let(:closed_date) { '2025-01-13T01:00:00Z' }
  let(:start_date) { Date.new(2025, 1, 1) }
  let(:due_date) { Date.new(2025, 1, 31) }

  let(:base_attrs) do
    %i[
      title confidential created_at updated_by_id last_edited_by_id
      last_edited_at closed_by_id closed_at
    ]
  end

  let(:params) do
    {
      title: 'new epic',
      description: 'epic description',
      parent: parent_epic,
      confidential: false,
      add_label_ids: [label2.id],
      label_ids: [label0.id],
      remove_label_ids: [label1.id],
      author: author,
      created_at: created_date,
      updated_by_id: user.id,
      last_edited_by_id: other_user.id,
      last_edited_at: edited_date,
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

  subject(:execute) { described_class.new(group: group, current_user: user, params: params).execute }

  before do
    stub_licensed_features(epics: true, subepics: true, epic_colors: true)
  end

  shared_examples 'success' do
    it 'creates a legacy epic and a work item epic' do
      expect { execute }.to change { Epic.count }.by(1).and change { WorkItem.count }.by(1)

      new_epic = Epic.last

      expect(new_epic.errors.empty?).to be(true)
      expect(new_epic.attributes.with_indifferent_access.values_at(*base_attrs)).to eq(params.values_at(*base_attrs))
      expect(new_epic.description).to eq('epic description')
      expect(new_epic.state_id).to eq(Epic.available_states['closed'])
      expect(new_epic.author).to eq(author)
      expect(new_epic.labels).to contain_exactly(label0, label2)
      expect(new_epic.confidential).to be_falsey
      expect(new_epic.color.to_s).to eq('#c91c00')
      expect(new_epic.start_date_is_fixed).to be_truthy
      expect(new_epic.due_date_is_fixed).to be_truthy
      expect(new_epic.due_date_fixed).to eq(due_date)
      expect(new_epic.start_date_fixed).to eq(start_date)

      diff = Gitlab::EpicWorkItemSync::Diff.new(new_epic, new_epic.work_item, strict_equal: true)
      expect(diff.attributes).to be_empty
    end

    context 'when setting a parent' do
      shared_examples 'creates new epic with a parent' do
        it 'creates sets the parent and create a new work item parent link' do
          expect { execute }.to change { WorkItems::ParentLink.count }.by(1)

          new_epic = Epic.last
          expect(new_epic.errors.empty?).to be(true)
          expect(execute).to eq(new_epic)
          expect(new_epic.relative_position).not_to be_nil
          expect(new_epic.parent).to eq(parent_epic)
          expect(new_epic.work_item_parent_link).to eq(new_epic.work_item.parent_link)
          expect(new_epic.work_item.work_item_parent).to eq(parent_epic.work_item)
        end
      end

      shared_examples 'does not create an epic' do
        it 'returns an epic record with errors' do
          new_epic = execute
          expect { new_epic }.to not_change { Epic.count }
                            .and not_change { WorkItem.count }
                            .and not_change { WorkItems::ParentLink.count }

          expect(new_epic.errors.full_messages).to contain_exactly(parent_not_found_error)
          expect(new_epic.parent_id).to be_nil
          expect(new_epic.work_item_parent_link_id).to be_nil
        end
      end

      context 'when parent param is present' do
        it_behaves_like 'creates new epic with a parent'
      end

      context 'when parent_id param is present' do
        let(:params) { super().merge(parent_id: parent_epic.id) }

        it_behaves_like 'creates new epic with a parent'
      end

      context 'when subepics are not supported for the group' do
        let(:params) { super().merge(parent: parent_epic) }

        before do
          stub_licensed_features(epics: true, subepics: false)
        end

        it_behaves_like 'does not create an epic'
      end

      context 'when user has no access to the parent epic' do
        let_it_be(:no_access_parent) { create(:epic, :with_synced_work_item, group: group_without_access) }

        let(:params) { super().merge(parent: no_access_parent) }

        it_behaves_like 'does not create an epic'
      end
    end
  end

  shared_examples 'when without_rate_limiting argument is present' do
    it 'calls execute_without_rate_limiting on the delegated service' do
      expect_next_instance_of(delegated_service) do |service_instance|
        allow(service_instance).to receive(:execute_without_rate_limiting).and_call_original
        expect(service_instance).to receive(:execute_without_rate_limiting).once
      end

      described_class.new(group: group, current_user: user, params: params).execute(without_rate_limiting: true)
    end
  end

  describe '#execute' do
    it_behaves_like 'success' do
      let(:parent_not_found_error) do
        'No matching epic found. Make sure that you are adding a valid epic URL.'
      end
    end

    it_behaves_like 'when without_rate_limiting argument is present' do
      let(:delegated_service) { ::WorkItems::CreateService }
    end

    it 'calls the WorkItems::CreateService with the correct params' do
      allow(::WorkItems::CreateService).to receive(:new).and_call_original

      expect(::WorkItems::CreateService).to receive(:new).with(
        a_hash_including(
          container: group,
          current_user: user,
          perform_spam_check: true,
          params: {
            title: "new epic",
            confidential: false,
            author: author,
            created_at: created_date,
            updated_by_id: user.id,
            last_edited_by_id: other_user.id,
            last_edited_at: edited_date,
            closed_by_id: other_user.id,
            closed_at: closed_date,
            state_id: 2,
            work_item_type: build(:work_item_system_defined_type, :epic)
          },
          widget_params: a_hash_including(
            description_widget: { description: "epic description" },
            color_widget: { color: '#c91c00' },
            hierarchy_widget: { parent: parent_epic.work_item },
            start_and_due_date_widget: { is_fixed: true, due_date: due_date, start_date: start_date },
            labels_widget: { add_label_ids: [label2.id], label_ids: [label0.id], remove_label_ids: [label1.id] }
          )
        )
      ).and_call_original

      execute
    end

    context 'when response include errors' do
      context 'with epic validation errors' do
        let_it_be(:confidential_parent) { create(:epic, :with_synced_work_item, :confidential, group: group) }
        let(:params) { super().merge(parent: confidential_parent) }
        let(:error_message) do
          "#{confidential_parent.work_item.to_reference} cannot be added: cannot assign " \
            "a non-confidential epic to a confidential parent. " \
            "Make the epic confidential and try again."
        end

        it 'returns epic with errors' do
          new_epic = execute
          expect(new_epic.errors.full_messages).to include(error_message)
        end
      end

      context 'when work item creation returns errors' do
        before do
          allow_next_instance_of(::WorkItems::CreateService) do |instance|
            allow(instance).to receive(:execute)
              .and_return(ServiceResponse.error(message: 'error message', payload: { work_item: nil }))
          end
        end

        it 'does not persist epic or work item' do
          expect { execute }.to not_change { Epic.count }.and not_change { WorkItem.count }
          expect(execute.errors.full_messages).to contain_exactly('error message')
        end
      end
    end

    context 'when description param has quick action' do
      context 'for /set_parent' do
        shared_examples 'assigning a valid parent epic' do
          let_it_be(:description) { "/set_parent #{parent_epic.to_reference(group, full: true)}" }
          let_it_be(:params, freeze: false) { { title: 'New epic with parent', description: description } }

          it 'sets parent epic' do
            expect(execute.reset.parent).to eq(parent_epic)
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
            let_it_be(:params, freeze: false) { { title: 'New epic with parent', description: description } }

            it 'does not set parent epic but still creates the epic' do
              expect { execute }.to not_change { WorkItems::ParentLink.count }
                .and change { WorkItem.count }.by(1)
                .and change { Epic.count }.by(1)

              expect(execute.reload.parent).to be_nil
            end
          end
        end

        context 'for /add_child' do
          let_it_be(:child_epic)  { create(:work_item, :epic_with_legacy_epic, namespace: group) }
          let_it_be(:description) { "/add_child #{child_epic.to_reference}" }
          let_it_be(:params, freeze: false) { { title: 'New epic with child', description: description } }

          it 'sets a child epic' do
            expect { execute }.to change { WorkItems::ParentLink.count }.by(1)
              .and change { WorkItem.count }.by(1)
              .and change { Epic.count }.by(1)

            expect(execute.reload.children).to include(child_epic.sync_object)
          end

          context 'when child epic cannot be assigned' do
            let(:other_group) { create(:group, :private) }
            let(:child_epic) { create(:work_item, :epic_with_legacy_epic, namespace: other_group) }

            it 'does not set child epic' do
              expect { execute }.to not_change { WorkItems::ParentLink.count }
                .and change { WorkItem.count }.by(1)
                .and change { Epic.count }.by(1)

              expect(execute.reload.children).to be_empty
            end
          end
        end
      end
    end
  end
end
