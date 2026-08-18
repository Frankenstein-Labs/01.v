# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Epics::TreeReorderService, feature_category: :portfolio_management do
  include LegacyEpicsHelper
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:ancestor) { create(:group) }
    let_it_be(:group) { create(:group, parent: ancestor) }
    let_it_be(:project) { create(:project, group: group) }

    let(:epic) { create(:epic, group: group) }
    let(:epic1) { create(:epic, group: group, parent: epic, relative_position: 10) }
    let(:epic2) { create(:epic, group: group, parent: epic, relative_position: 20) }
    let(:issue1) { create(:issue, project: project, epic: epic, epic_issue_relative_position: 30) }
    let(:issue2) { create(:issue, project: project, epic: epic, epic_issue_relative_position: 40) }

    let(:relative_position) { 'after' }
    let!(:tree_object_1) { epic1 }
    let!(:tree_object_2) { epic2 }
    let(:adjacent_reference_id) { GitlabSchema.id_from_object(tree_object_1) }
    let(:moving_object_id) { GitlabSchema.id_from_object(tree_object_2) }
    let(:new_parent_id) { nil }
    let(:params) do
      {
        base_epic_id: GitlabSchema.id_from_object(epic),
        adjacent_reference_id: adjacent_reference_id,
        relative_position: relative_position,
        new_parent_id: new_parent_id
      }
    end

    subject(:reorder) { described_class.new(user, moving_object_id, params).execute }

    shared_examples 'error for the tree update' do |expected_error|
      it 'does not change anything', :aggregate_failures do
        expect { reorder }.not_to change { tree_object_1.reload.relative_position }
        expect { reorder }.not_to change { tree_object_2.reload.relative_position }
        expect { reorder }.not_to change { tree_object_2.reload.parent }

        expect(reorder[:status]).to eq(:error)
        expect(reorder[:message]).to eq(expected_error)
      end
    end

    context 'when epics feature is not enabled' do
      it_behaves_like 'error for the tree update', 'You don\'t have permissions to move the objects.'
    end

    context 'when epics feature is enabled' do
      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      context 'when user does not have permissions to admin the base epic' do
        it_behaves_like 'error for the tree update', 'You don\'t have permissions to move the objects.'
      end

      context 'when user does have admin_issue_relation permission for the base epic' do
        before_all do
          group.add_guest(user)
        end

        context 'when moving EpicIssue' do
          let!(:tree_object_1) { issue1.epic_issue }
          let!(:tree_object_2) { issue2.epic_issue }

          context 'when relative_position is not valid' do
            let(:relative_position) { 'whatever' }

            it_behaves_like 'error for the tree update', 'Relative position is not valid.'
          end

          context 'when object being moved is not the same type as the switched object' do
            let!(:tree_object_3) { epic1 }
            let!(:tree_object_4) { epic2 }
            let(:adjacent_reference_id) { GitlabSchema.id_from_object(epic2) }

            it 'reorders the objects' do
              reorder

              expect(epic2.reload.relative_position).to be > tree_object_2.reload.relative_position
            end
          end

          context 'when no object to switch is provided' do
            let(:adjacent_reference_id) { nil }
            let(:new_parent_id) { GitlabSchema.id_from_object(epic) }

            before do
              tree_object_2.work_item_parent_link.update!(work_item_parent: epic1.work_item)
              tree_object_2.update!(epic: epic1)
            end

            it 'updates the parent' do
              expect { reorder }.to change { tree_object_2.reload.epic }.from(epic1).to(epic)
            end

            it 'creates system notes' do
              # 3 because now we add system note to old parent indicating child has been 'moved'
              expect { reorder }.to change { Note.system.count }.by(3)
            end
          end

          context 'when object being moved is from another epic' do
            before do
              other_epic = create(:epic, group: group)
              issue2.epic_issue.work_item_parent_link.update!(work_item_parent: other_epic.work_item)
              issue2.epic_issue.update!(epic: other_epic)
            end

            context 'when the new_parent_id has not been provided' do
              it_behaves_like 'error for the tree update',
                "The sibling object's parent must match the current parent epic."
            end

            context 'when the new_parent_id does not match the parent of the relative positioning object' do
              let(:unrelated_epic) { create(:epic, group: group) }
              let(:new_parent_id) { GitlabSchema.id_from_object(unrelated_epic) }

              it_behaves_like 'error for the tree update', "The sibling object's parent must match the new parent epic."
            end

            context 'when the new_parent_id matches the parent id of the relative positioning object' do
              let(:new_parent_id) { GitlabSchema.id_from_object(epic) }

              shared_examples 'reorder objects and returns success status' do
                it 'reorders the objects' do
                  expect(reorder[:status]).to eq(:success)
                  expect(reorder[:message]).to be_nil
                  expect(epic2.reload.relative_position).to be > tree_object_2.reload.relative_position
                end
              end

              it_behaves_like 'reorder objects and returns success status'
            end
          end

          context 'when object being moved is not supported type' do
            let(:moving_object_id) { GitlabSchema.id_from_object(issue1) }

            it_behaves_like 'error for the tree update', 'Only epics and epic_issues are supported.'
          end

          context 'when adjacent object is not supported type' do
            let(:adjacent_reference_id) { GitlabSchema.id_from_object(issue2) }

            it_behaves_like 'error for the tree update', 'Only epics and epic_issues are supported.'
          end

          context 'when user does not have permissions to move issue' do
            let_it_be(:private_project) { create(:project, :private) }
            let(:private_issue1) do
              create(:issue, project: private_project, epic: epic, epic_issue_relative_position: 50)
            end

            let(:private_issue2) do
              create(:issue, project: private_project, epic: epic, epic_issue_relative_position: 60)
            end

            let!(:tree_object_1) { private_issue1.epic_issue }
            let!(:tree_object_2) { private_issue2.epic_issue }

            it_behaves_like 'error for the tree update', 'You don\'t have permissions to move the objects.'
          end

          context 'when user does not have permissions to admin the previous parent' do
            let(:other_epic) { create(:epic, group: ancestor) }
            let(:new_parent_id) { GitlabSchema.id_from_object(epic) }

            before do
              issue2.epic_issue.work_item_parent_link.update!(work_item_parent: other_epic.work_item)
              issue2.epic_issue.update!(parent: other_epic)
            end

            it_behaves_like 'error for the tree update', 'You don\'t have permissions to move the objects.'
          end

          context 'when user does not have permissions to admin the new parent' do
            let(:other_epic) { create(:epic, group: ancestor) }
            let(:new_parent_id) { GitlabSchema.id_from_object(other_epic) }

            it_behaves_like 'error for the tree update', 'You don\'t have permissions to move the objects.'
          end

          context 'when the epics of reordered epic-issue links are not subepics of the base epic' do
            let(:another_epic) { create(:epic, group: ancestor) }

            before do
              issue1.epic_issue.work_item_parent_link.update!(work_item_parent: another_epic.work_item)
              issue1.epic_issue.update!(epic: another_epic)

              issue2.epic_issue.work_item_parent_link.update!(work_item_parent: another_epic.work_item)
              issue2.epic_issue.update!(epic: another_epic)
            end

            context 'when new_parent_id is not provided' do
              it_behaves_like 'error for the tree update', 'You don\'t have permissions to move the objects.'
            end

            context 'when new_parent_id is provided' do
              let(:new_parent_id) { GitlabSchema.id_from_object(epic) }

              it_behaves_like 'error for the tree update', 'You don\'t have permissions to move the objects.'
            end
          end

          context 'when moving is successful' do
            it 'updates the links relative positions' do
              reorder

              expect(tree_object_1.reload.relative_position).to be > tree_object_2.reload.relative_position
            end

            context 'when a new_parent_id of a valid parent is provided' do
              let(:new_parent_id) { GitlabSchema.id_from_object(epic) }

              before do
                issue2.epic_issue.work_item_parent_link.update!(work_item_parent: epic1.work_item)
                issue2.epic_issue.update!(epic: epic1)
              end

              it 'updates the parent' do
                expect { reorder }.to change { tree_object_2.reload.epic }.from(epic1).to(epic)
              end

              it 'updates the links relative positions' do
                reorder

                expect(tree_object_1.reload.relative_position).to be > tree_object_2.reload.relative_position
              end

              it 'creates system notes' do
                # 3 because now we add system note to old parent indicating child has been 'moved'
                expect { reorder }.to change { Note.system.count }.by(3)
              end
            end

            context 'with synced epic work items' do
              context 'when moving to a new parent' do
                let(:new_parent_id) { GitlabSchema.id_from_object(new_parent) }
                let(:work_item_1) { WorkItem.find(issue1.id) }
                let(:work_item_2) { WorkItem.find(issue2.id) }
                let(:adjacent_reference_id) { nil }
                let(:moving_object_id) { GitlabSchema.id_from_object(issue2.epic_issue) }
                let(:moving_epic_issue) { issue2.epic_issue }
                let(:moving_parent_link) { work_item_2 }

                let_it_be(:old_parent) { create(:epic, :with_synced_work_item, group: group) }
                let_it_be(:new_parent) { create(:epic, :with_synced_work_item, group: group) }
                let_it_be_with_reload(:epic1) { old_parent }
                let_it_be_with_reload(:epic) { new_parent }

                let(:params) do
                  {
                    base_epic_id: GitlabSchema.id_from_object(old_parent),
                    adjacent_reference_id: adjacent_reference_id,
                    relative_position: relative_position,
                    new_parent_id: new_parent_id
                  }
                end

                context 'when new parent has no children' do
                  before do
                    issue1.epic_issue.work_item_parent_link.update!(work_item_parent: old_parent.work_item)
                    issue1.epic_issue.update!(epic: old_parent)

                    issue2.epic_issue.work_item_parent_link.update!(work_item_parent: old_parent.work_item)
                    issue2.epic_issue.update!(epic: old_parent)
                  end

                  it 'sets a new work item parent' do
                    expect { reorder }.to change { moving_epic_issue.reload.epic }.from(old_parent).to(new_parent)
                    .and change {
                           moving_parent_link.reload.work_item_parent
                         }.from(old_parent.work_item).to(new_parent.work_item)

                    expect(moving_epic_issue.relative_position).to eq(moving_parent_link.relative_position)

                    expect(reorder[:status]).to eq(:success)
                  end

                  it 'keeps epics timestamps in sync' do
                    expect(reorder[:status]).to eq(:success)

                    expect(old_parent.updated_at).to eq(old_parent.work_item.updated_at)
                    expect(new_parent.updated_at).to eq(new_parent.work_item.updated_at)
                  end

                  context 'when the new parent has no synced work item' do
                    let_it_be_with_reload(:new_parent) { create(:epic, group: group) }

                    it 'only sets the new parent for the epic_issue' do
                      expect { reorder }.to change { moving_epic_issue.reload.epic }.from(old_parent).to(new_parent)
                      expect { reorder }.to not_change { moving_parent_link.reload.work_item_parent }
                      expect(reorder[:status]).to eq(:success)
                    end
                  end

                  context 'when syncing to the work item fails' do
                    before do
                      allow_next_instance_of(WorkItems::ParentLinks::CreateService) do |instance|
                        allow(instance).to receive(:execute).and_return({ status: :error, message: 'error message' })
                      end
                    end

                    it 'does not set new work item parent' do
                      expect { reorder }.not_to change { moving_epic_issue.reload.epic }
                      expect { reorder }.not_to change { moving_parent_link.reload.work_item_parent }
                      expect(reorder[:status]).to eq(:error)
                    end
                  end
                end

                # -- needed for the context
                context 'when new parent has children' do
                  let(:adjacent_reference_id) { GitlabSchema.id_from_object(issue1.epic_issue) }
                  let(:parent_link1) { issue1.epic_issue.work_item_parent_link }
                  let(:parent_link2) { issue2.epic_issue.work_item_parent_link }

                  before do
                    issue1.epic_issue.work_item_parent_link.update!(work_item_parent: new_parent.work_item)
                    issue2.epic_issue.work_item_parent_link.update!(work_item_parent: old_parent.work_item)

                    issue1.epic_issue.update!(epic: new_parent)
                    issue2.epic_issue.update!(epic: old_parent)
                  end

                  context 'when relative_position is before' do
                    let(:relative_position) { 'before' }

                    it 'updates the work item parent and sets it after the adjacent item', :aggregate_failures do
                      expect { reorder }.to change { moving_epic_issue.reload.epic }.from(old_parent).to(new_parent)
                        .and change { work_item_2.reload.work_item_parent }
                        .from(old_parent.work_item).to(new_parent.work_item)

                      expect(issue2.epic_issue.reload.relative_position).to be >
                        issue1.epic_issue.reload.relative_position
                      expect(parent_link2.reload.relative_position).to be > parent_link1.reload.relative_position
                      expect(parent_link2.relative_position).to eq(issue2.epic_issue.reload.relative_position)
                      expect(reorder[:status]).to eq(:success)
                    end
                  end

                  context 'when relative_position is after' do
                    let(:relative_position) { 'after' }

                    it 'updates the work item parent and sets it before the adjacent item' do
                      expect { reorder }.to change { moving_epic_issue.reload.epic }.from(old_parent).to(new_parent)
                        .and change { work_item_2.reload.work_item_parent }
                          .from(old_parent.work_item).to(new_parent.work_item)

                      expect(parent_link2.reload.relative_position).to be < parent_link1.reload.relative_position
                      expect(parent_link2.relative_position).to eq(issue2.epic_issue.reload.relative_position)
                      expect(reorder[:status]).to eq(:success)
                    end
                  end

                  context 'when syncing to the work item fails' do
                    before do
                      allow_next_instance_of(WorkItems::ParentLinks::ReorderService) do |instance|
                        allow(instance).to receive(:execute).and_return({ status: :error, message: 'error message' })
                      end
                    end

                    it 'does not set new work item parent' do
                      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
                        instance_of(Epics::SyncAsWorkItem::SyncAsWorkItemError),
                        { moving_object_id: moving_epic_issue.id,
                          moving_object_class: 'EpicIssue' }
                      )

                      expect { reorder }.not_to change { parent_link1.reload.relative_position }
                      expect { reorder }.not_to change { work_item_1.reload.work_item_parent }
                      expect { reorder }.not_to change { parent_link2.reload.relative_position }
                      expect { reorder }.not_to change { work_item_2.reload.work_item_parent }
                      expect(reorder).to eq(
                        status: :error, message: "Couldn't perform re-order due to an internal error.", http_status: 422
                      )
                    end
                  end
                end
              end

              context 'when reordering within the same parent' do
                let(:relative_position) { 'after' }

                let_it_be(:synced_epic) { create(:epic, :with_synced_work_item, group: group) }
                let_it_be(:issue1) do
                  create(:issue, project: project, epic: synced_epic, epic_issue_relative_position: 10)
                end

                let_it_be(:issue2) do
                  create(:issue, project: project, epic: synced_epic, epic_issue_relative_position: 20)
                end

                let_it_be(:parent_link1) do
                  issue1.epic_issue.work_item_parent_link
                end

                let_it_be(:parent_link2) do
                  issue2.epic_issue.work_item_parent_link
                end

                let(:params) do
                  {
                    base_epic_id: GitlabSchema.id_from_object(synced_epic),
                    adjacent_reference_id: GitlabSchema.id_from_object(issue1.epic_issue),
                    relative_position: relative_position
                  }
                end

                context 'when relative_position is after' do
                  let(:relative_position) { 'after' }

                  it 'updates the relative positions', :aggregate_failures do
                    reorder

                    expect(issue1.epic_issue.reload.relative_position).to be >
                      issue2.epic_issue.reload.relative_position
                    expect(parent_link1.reload.relative_position).to be > parent_link2.reload.relative_position
                    expect(parent_link1.reload.relative_position).to eq(issue1.epic_issue.relative_position)
                  end
                end

                context 'when relative_position is before' do
                  let(:relative_position) { 'before' }

                  it 'updates the relative positions', :aggregate_failures do
                    reorder

                    expect(issue1.epic_issue.reload.relative_position).to be <
                      issue2.epic_issue.reload.relative_position
                    expect(parent_link1.reload.relative_position).to be < parent_link2.reload.relative_position
                    expect(parent_link1.reload.relative_position).to eq(issue1.epic_issue.relative_position)
                  end
                end
              end
            end
          end
        end

        context 'when moving Epic' do
          let!(:tree_object_1) { epic1 }
          let!(:tree_object_2) { epic2 }

          context 'when subepics feature is disabled' do
            let(:new_parent_id) { GitlabSchema.id_from_object(epic) }

            before do
              stub_licensed_features(epics: true, subepics: false)
            end

            it_behaves_like 'error for the tree update', 'You don\'t have permissions to move the objects.'
          end

          context 'when subepics feature is enabled' do
            before do
              stub_licensed_features(epics: true, subepics: true)
            end

            context 'when relative_position is not valid' do
              let(:relative_position) { 'whatever' }

              it_behaves_like 'error for the tree update', 'Relative position is not valid.'
            end

            context 'when user does not have permissions to admin the previous parent' do
              let(:other_epic) { create(:epic, group: ancestor) }
              let(:new_parent_id) { GitlabSchema.id_from_object(epic) }

              before do
                assign_epic_parent(epic2, other_epic)
              end

              it_behaves_like 'error for the tree update', 'You don\'t have permissions to move the objects.'
            end

            context 'when user does not have permissions to admin the previous parent links' do
              let(:new_parent_id) { GitlabSchema.id_from_object(epic) }

              before do
                user.group_members.delete_all
              end

              it_behaves_like 'error for the tree update', 'You don\'t have permissions to move the objects.'
            end

            context 'when there is some other error with the new parent' do
              shared_examples 'new parent not in an ancestor group' do
                it 'returns success status without errors', :aggregate_failures do
                  expect(reorder[:status]).to eq(:success)
                  expect(reorder[:message]).to be_nil
                end
              end

              context 'when the new parent is in a new group hierarchy' do
                let_it_be(:other_group) { create(:group) }

                let(:new_parent_id) { GitlabSchema.id_from_object(epic) }

                before do
                  other_group.add_developer(user)
                  epic.update!(group: other_group)
                  epic.work_item.update!(namespace: other_group)
                  assign_epic_parent(epic2, epic1)
                end

                it_behaves_like 'new parent not in an ancestor group'
              end

              context 'when the new parent is in a descendant group' do
                let_it_be(:descendant_group) { create(:group, parent: group) }

                let(:new_parent_id) { GitlabSchema.id_from_object(epic) }

                before do
                  descendant_group.add_developer(user)
                  epic.update!(group: descendant_group)
                  epic.work_item.update!(namespace: descendant_group)

                  assign_epic_parent(epic2, epic1)
                end

                it_behaves_like 'new parent not in an ancestor group'
              end
            end

            context 'when user does not have permissions to admin the new parent' do
              let(:other_epic) { create(:epic, group: ancestor) }
              let(:new_parent_id) { GitlabSchema.id_from_object(other_epic) }

              it_behaves_like 'error for the tree update', 'You don\'t have permissions to move the objects.'
            end

            context 'when the reordered epics are not subepics of the base epic' do
              let(:another_group) { create(:group) }
              let(:another_epic) { create(:epic, group: another_group) }

              before do
                epic1.assign_attributes(group: ancestor)
                assign_epic_parent(epic1, another_epic)

                epic2.assign_attributes(group: ancestor)
                assign_epic_parent(epic2, another_epic)
              end

              it_behaves_like 'error for the tree update', 'You don\'t have permissions to move the objects.'
            end

            context 'when moving is successful' do
              it 'updates the links relative positions' do
                reorder

                expect(tree_object_1.reload.relative_position).to be > tree_object_2.reload.relative_position
              end

              context 'when new parent is current epic' do
                let(:new_parent_id) { GitlabSchema.id_from_object(epic) }

                it 'updates the relative positions' do
                  reorder

                  expect(tree_object_1.reload.relative_position).to be > tree_object_2.reload.relative_position
                end

                it 'does not update the parent_id' do
                  expect { reorder }.not_to change { tree_object_2.reload.parent }
                end
              end

              context 'when moved object is from another epic and new_parent_id matches parent of adjacent object' do
                let(:other_epic) { create(:epic, group: group) }
                let(:new_parent_id) { GitlabSchema.id_from_object(epic) }
                let(:epic3) { create(:epic, parent: other_epic, group: group) }
                let(:tree_object_2) { epic3 }

                it 'updates the relative positions' do
                  reorder

                  expect(tree_object_1.reload.relative_position).to be > tree_object_2.reload.relative_position
                end

                it 'updates the parent' do
                  expect { reorder }.to change { tree_object_2.reload.parent }.from(other_epic).to(epic)
                end

                it 'creates system notes' do
                  # 3 because now we add system note to old parent indicating child has been 'moved'
                  expect { reorder }.to change { Note.system.count }.by(3)
                end
              end

              context 'with synced epic work items' do
                context 'when moving to a new parent' do
                  let(:new_parent_id) { GitlabSchema.id_from_object(new_parent) }
                  let(:adjacent_reference_id) { nil }
                  let(:moving_object_id) { GitlabSchema.id_from_object(moving_epic) }

                  let_it_be_with_reload(:old_parent) { create(:epic, :with_synced_work_item, group: group) }
                  let_it_be(:new_parent) { create(:epic, :with_synced_work_item, group: group) }

                  let_it_be_with_refind(:moving_epic) do
                    create(:epic, :with_synced_work_item, group: group, parent: old_parent, relative_position: 20)
                  end

                  let(:params) do
                    {
                      base_epic_id: GitlabSchema.id_from_object(old_parent),
                      adjacent_reference_id: adjacent_reference_id,
                      relative_position: relative_position,
                      new_parent_id: new_parent_id
                    }
                  end

                  shared_examples 'moves to a parent without children' do
                    it 'sets a new work item parent' do
                      expect { reorder }.to change { moving_epic.reload.parent }.from(old_parent).to(new_parent).and(
                        change { moving_epic.work_item.reload.work_item_parent }
                          .from(moving_object_parent_link&.work_item_parent).to(new_parent.work_item)
                      )

                      expect(moving_epic.relative_position).to eq(
                        moving_epic.work_item.reload.parent_link.relative_position
                      )
                      expect(reorder[:status]).to eq(:success)
                    end

                    context 'when syncing to the work item fails' do
                      before do
                        allow_next_instance_of(WorkItems::ParentLinks::CreateService) do |instance|
                          allow(instance).to receive(:execute).and_return({ status: :error, message: 'error message' })
                        end
                      end

                      it 'does not set new epic or work item parent' do
                        expect { reorder }.to not_change { moving_epic.reload.parent }
                          .and not_change { moving_epic.work_item.reload.work_item_parent }
                        expect(reorder[:status]).to eq(:error)
                      end
                    end
                  end

                  context 'when new parent has no children' do
                    context 'when moving object has parent link relationship' do
                      let_it_be_with_refind(:moving_object_parent_link) { moving_epic.work_item_parent_link }

                      it_behaves_like 'moves to a parent without children'
                    end
                  end

                  context 'when new parent has children' do
                    let_it_be(:adjacent_epic) do
                      create(:epic, :with_synced_work_item, parent: new_parent, group: group, relative_position: 10)
                    end

                    let_it_be_with_reload(:moving_object_parent_link) { moving_epic.work_item_parent_link }

                    shared_examples 'moves epic to a parent with children' do
                      let(:adjacent_reference_id) { GitlabSchema.id_from_object(adjacent_epic) }

                      context 'when relative_position is before' do
                        let(:relative_position) { 'before' }

                        it 'updates the work item parent and sets it after the adjacent item', :aggregate_failures do
                          expect { reorder }.to change { moving_epic.reload.parent }.from(old_parent).to(new_parent)
                            .and change { moving_epic.work_item.reload.work_item_parent }
                            .from(old_parent.work_item).to(new_parent.work_item)

                          expect(adjacent_epic.reload.relative_position).to be < moving_epic.reload.relative_position
                          expect(adjacent_epic.work_item.reload.parent_link.relative_position)
                            .to be < moving_object_parent_link.reload.relative_position

                          expect(moving_object_parent_link.reload.relative_position)
                            .to eq(moving_epic.reload.relative_position)

                          expect(reorder[:status]).to eq(:success)
                        end
                      end

                      context 'when relative_position is after' do
                        let(:relative_position) { 'after' }

                        it 'updates the work item parent and sets it before the adjacent item', :aggregate_failures do
                          expect { reorder }.to change { moving_epic.reload.parent }.from(old_parent).to(new_parent)
                            .and change { moving_epic.work_item.reload.work_item_parent }
                            .from(old_parent.work_item).to(new_parent.work_item)

                          expect(adjacent_epic.reload.relative_position).to be > moving_epic.reload.relative_position
                          expect(adjacent_epic.work_item.reload.parent_link.relative_position)
                            .to be > moving_object_parent_link.reload.relative_position

                          expect(moving_object_parent_link.reload.relative_position)
                            .to eq(moving_epic.reload.relative_position)

                          expect(reorder[:status]).to eq(:success)
                        end
                      end
                    end

                    context 'when adjacent epic work item does not have a parent link relationship' do
                      it_behaves_like 'moves epic to a parent with children'
                    end

                    context 'when adjacent epic work item has a parent link relationship' do
                      let_it_be(:adjacent_parent_link) { adjacent_epic.work_item_parent_link }

                      it_behaves_like 'moves epic to a parent with children'
                    end
                  end
                end

                context 'when reordering within the same parent' do
                  let(:relative_position) { 'after' }
                  let(:moving_object_id) { GitlabSchema.id_from_object(moving_epic) }
                  let(:adjacent_reference_id) { GitlabSchema.id_from_object(adjacent_epic) }

                  let_it_be(:parent) { create(:epic, :with_synced_work_item, group: group) }

                  let_it_be_with_reload(:adjacent_epic) do
                    create(:epic, :with_synced_work_item, parent: parent, group: group, relative_position: 10)
                  end

                  let_it_be_with_reload(:adjacent_parent_link) { adjacent_epic.work_item_parent_link }

                  let_it_be_with_reload(:moving_epic) do
                    create(:epic, :with_synced_work_item, group: group, parent: parent, relative_position: 20)
                  end

                  let_it_be_with_reload(:moving_object_parent_link) { moving_epic.work_item_parent_link }

                  let(:params) do
                    {
                      base_epic_id: GitlabSchema.id_from_object(parent),
                      adjacent_reference_id: adjacent_reference_id,
                      relative_position: relative_position
                    }
                  end

                  context 'when relative_position is after' do
                    let(:relative_position) { 'after' }

                    it 'updates the relative positions', :aggregate_failures do
                      reorder

                      expect(adjacent_epic.reload.relative_position).to be > moving_epic.reload.relative_position
                      expect(adjacent_parent_link.reload.relative_position)
                        .to be > moving_object_parent_link.reload.relative_position

                      expect(moving_object_parent_link.reload.relative_position)
                        .to eq(moving_epic.reload.relative_position)

                      expect(reorder[:status]).to eq(:success)
                    end
                  end

                  context 'when relative_position is before' do
                    let(:relative_position) { 'before' }

                    it 'updates the relative positions', :aggregate_failures do
                      reorder

                      expect(adjacent_epic.reload.relative_position).to be < moving_epic.reload.relative_position
                      expect(adjacent_parent_link.reload.relative_position)
                        .to be < moving_object_parent_link.reload.relative_position

                      expect(moving_object_parent_link.reload.relative_position)
                        .to eq(moving_epic.reload.relative_position)

                      expect(reorder[:status]).to eq(:success)
                    end
                  end

                  context 'when syncing to the work item fails' do
                    before do
                      allow_next_instance_of(WorkItems::ParentLinks::ReorderService) do |instance|
                        allow(instance).to receive(:execute).and_return({ status: :error, message: 'error message' })
                      end
                    end

                    it 'does not change the position' do
                      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
                        instance_of(Epics::SyncAsWorkItem::SyncAsWorkItemError),
                        { moving_object_id: moving_epic.id,
                          moving_object_class: 'Epic' }
                      )

                      expect { reorder }.to not_change { moving_object_parent_link.reload.relative_position }
                        .and not_change { moving_epic.reload.relative_position }
                        .and not_change { adjacent_epic.reload.relative_position }
                        .and not_change { adjacent_parent_link.reload.relative_position }

                      expect(reorder).to eq(
                        status: :error, message: "Couldn't perform re-order due to an internal error.", http_status: 422
                      )
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
