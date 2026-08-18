# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::Widgets::Hierarchy, feature_category: :team_planning do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:another_group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:another_project) { create(:project, group: another_group) }

  let(:params) { { operation: :move } }

  before_all do
    group.add_developer(current_user)
    another_group.add_developer(current_user)
  end

  subject(:callback) do
    described_class.new(
      work_item: work_item, target_work_item: target_work_item, current_user: current_user, params: params
    )
  end

  describe "for children related hierarchy data" do
    let_it_be(:target_work_item) { create(:work_item, :epic_with_legacy_epic, namespace: another_group) }
    let_it_be(:work_item) do
      create(:work_item, :epic_with_legacy_epic, namespace: group).tap do |parent|
        # child issue with legacy epic_issue relationship
        create(:work_item, :issue).tap do |work_item|
          link = create(:parent_link, work_item: work_item, work_item_parent: parent)
          create(:epic_issue, epic: parent.sync_object, issue: work_item, work_item_parent_link: link)
        end
        # child epic with legacy parent_id relationship
        create(:work_item, :epic_with_legacy_epic).tap do |work_item|
          link = create(:parent_link, work_item: work_item, work_item_parent: parent)
          work_item.sync_object.update!(parent_id: parent.sync_object.id, work_item_parent_link: link)
        end
      end
    end

    describe '#after_save_commit' do
      context 'when target work item has hierarchy widget' do
        before do
          allow(target_work_item).to receive(:get_widget).with(:hierarchy).and_return(true)
        end

        context 'when operation: promote' do
          let(:params) { { operation: :promote } }

          it 'does not copy children or parent hierarchy data' do
            expect(callback).not_to receive(:handle_parent).and_call_original
            expect(callback).not_to receive(:handle_children).and_call_original

            callback.after_save_commit
          end
        end

        context 'when operation: clone' do
          let(:params) { { operation: :clone } }

          it 'does not copy children or parent hierarchy data' do
            expect(callback).to receive(:handle_parent).and_call_original
            expect(callback).not_to receive(:handle_children).and_call_original

            callback.after_save_commit
          end
        end

        it 'copies hierarchy data from work_item to target_work_item' do
          expect(callback).to receive(:handle_parent).and_call_original
          expect(callback).to receive(:handle_children).and_call_original

          source_sync_obj = work_item.sync_object
          source_work_item_children_titles = work_item.work_item_children.map(&:title)
          source_epic_titles = source_sync_obj.children.map(&:title)
          source_epic_issues_titles = source_sync_obj.issues.map(&:title)
          source_epic_parent_links = source_sync_obj.children.map(&:work_item_parent_link_id)
          source_issues_parent_links = source_sync_obj.epic_issues.map(&:work_item_parent_link_id)

          expect { callback.after_save_commit }.to not_change { Epic.count }.and(not_change { EpicIssue.count })

          target_sync_obj = target_work_item.sync_object.reload
          expect(target_sync_obj.children.map(&:title)).to match_array(source_epic_titles)
          expect(target_sync_obj.children.map(&:work_item_parent_link_id)).to match_array(source_epic_parent_links)
          expect(target_sync_obj.issues.map(&:title)).to match_array(source_epic_issues_titles)
          expect(target_sync_obj.epic_issues.map(&:work_item_parent_link_id)).to match_array(source_issues_parent_links)

          expect(target_work_item.reload.work_item_children.map(&:title))
            .to match_array(source_work_item_children_titles)
          expect(target_work_item.namespace.work_items).to match_array([target_work_item])

          expect(work_item.reload.work_item_children).to be_empty
          expect(source_sync_obj.reload.children).to be_empty
          expect(source_sync_obj.reload.issues).to be_empty
        end
      end

      context 'when target work item does not have hierarchy widget' do
        before do
          target_work_item.reload
          allow(target_work_item).to receive(:get_widget).with(:hierarchy).and_return(false)
        end

        it 'does not copy hierarchy data' do
          expect(callback).not_to receive(:new_work_item_child_link)
          expect(::WorkItems::ParentLink).not_to receive(:upsert_all)

          callback.after_save_commit

          expect(target_work_item.reload.work_item_children).to be_empty
        end
      end
    end
  end

  describe "for parent related hierarchy data" do
    let_it_be_with_reload(:work_item) { create(:work_item, :issue, project: project) }
    let_it_be_with_reload(:target_work_item) { create(:work_item, :issue, project: another_project) }
    let_it_be(:epic) { create(:epic, :with_synced_work_item, group: group) }

    describe '#after_create' do
      context 'when operation: move' do
        let(:params) { { operation: :move } }

        it 'does not copy children or parent hierarchy data' do
          expect(callback).not_to receive(:handle_parent).and_call_original
          expect(callback).not_to receive(:handle_children).and_call_original

          callback.after_create
        end
      end

      context 'when operation: clone' do
        let(:params) { { operation: :clone } }

        it 'does not copy children or parent hierarchy data' do
          expect(callback).not_to receive(:handle_parent).and_call_original
          expect(callback).not_to receive(:handle_children).and_call_original

          callback.after_create
        end
      end

      context 'when operation: promote' do
        let(:params) { { operation: :promote } }

        let_it_be_with_reload(:target_work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
        let_it_be_with_reload(:parent_link) do
          create(:parent_link, :with_epic_issue, work_item: work_item, work_item_parent: epic.work_item,
            relative_position: 20)
        end

        it "sets the correct data on the legacy epic parent relationship" do
          expect { callback.after_create }.to not_change { EpicIssue.count }
            .and change { WorkItems::ParentLink.count }.by(1)

          parent_link = target_work_item.parent_link
          parent_epic = target_work_item.sync_object.reload

          expect(parent_epic.parent).to eq(epic)
          expect(parent_epic.work_item_parent_link).to eq(parent_link)
          expect(parent_link.relative_position).to eq(parent_epic.relative_position)

          expect(target_work_item.epic_issue).to be_nil
          expect(parent_link.work_item_parent).to eq(epic.work_item)
        end
      end
    end

    describe '#after_save_commit' do
      it "does not copy the epic issue when there is none" do
        expect { callback.after_save_commit }.not_to change { target_work_item.reload.epic_issue }
      end

      context "when the work item does not have the hierarchy widget" do
        before do
          allow(target_work_item).to receive(:get_widget).with(:hierarchy).and_return(false)
        end

        it "does not copy the epic_issue" do
          expect { callback.after_save_commit }.not_to change { target_work_item.reload.epic_issue }
        end
      end

      context 'when work item to be moved is an issue with epic_issue record' do
        let_it_be_with_reload(:parent_link) do
          create(:parent_link, :with_epic_issue, work_item: work_item, work_item_parent: epic.work_item,
            relative_position: 20)
        end

        it "copies the epic issue to the target_work_item" do
          expect { callback.after_save_commit }.to change { target_work_item.reload.epic }.from(nil).to(epic)
        end

        it "creates a new epic issue record with correct data" do
          expect { callback.after_save_commit }.to change { EpicIssue.count }.by(1)
            .and change { WorkItems::ParentLink.count }.by(1)

          target_work_item.reload

          expect(target_work_item.epic_issue.work_item_parent_link).to eq(target_work_item.parent_link)
          expect(target_work_item.epic_issue.namespace_id).to eq(target_work_item.namespace_id)
          expect(target_work_item.epic_issue.relative_position).to eq(target_work_item.parent_link.relative_position)
        end
      end

      context 'when work item to be copied becomes an epic with epic_issue record' do
        let_it_be_with_reload(:target_work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
        let_it_be_with_reload(:parent_link) do
          create(:parent_link, :with_epic_issue, work_item: work_item, work_item_parent: epic.work_item,
            relative_position: 20)
        end

        it "sets the correct data on the legacy epic parent relationship" do
          expect { callback.after_save_commit }.to not_change { EpicIssue.count }
            .and change { WorkItems::ParentLink.count }.by(1)

          parent_link = target_work_item.parent_link
          parent_epic = target_work_item.sync_object.reload

          expect(parent_epic.parent).to eq(epic)
          expect(parent_epic.work_item_parent_link).to eq(parent_link)
          expect(parent_link.relative_position).to eq(parent_epic.relative_position)

          expect(target_work_item.epic_issue).to be_nil
          expect(parent_link.work_item_parent).to eq(epic.work_item)
        end
      end

      context "when work item to be moved is an epic" do
        let_it_be(:work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
        let_it_be(:target_work_item) { create(:work_item, :epic_with_legacy_epic, namespace: another_group) }

        # As a new work item is created, we need to recreate the parent_link
        let_it_be(:parent_link) do
          create(:parent_link, work_item: work_item, work_item_parent: epic.work_item, relative_position: 20).tap do |l|
            work_item.sync_object.update!(parent: epic, work_item_parent_link: l, relative_position: 20)
          end
        end

        it "copies the parent and the work_item_parent_link to the target epic" do
          child_epic = target_work_item.sync_object
          parent_epic = work_item.sync_object.parent

          callback.after_save_commit

          expect(child_epic.reload.parent).to eq(parent_epic)
          expect(child_epic.work_item_parent_link).to eq(target_work_item.reload.parent_link)
        end
      end
    end

    describe '#post_move_cleanup' do
      context 'when cleanup_data_source_work_item_data feature is enabled' do
        before do
          stub_feature_flags(cleanup_data_source_work_item_data: true)
        end

        context 'when work item to be moved is an issue with epic_issue record' do
          let_it_be(:parent_link) do
            create(:parent_link, :with_epic_issue, work_item: work_item, work_item_parent: epic.work_item,
              relative_position: 20)
          end

          it "clears the epic and deletes the epic_issue and the parent_link records" do
            expect { callback.post_move_cleanup }.to change { work_item.reload.epic }.from(epic).to(nil)
              .and change { EpicIssue.count }.by(-1)
              .and change { WorkItems::ParentLink.count }.by(-1)
          end
        end

        context "when work item to be moved is an epic" do
          let_it_be(:work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
          let_it_be(:target_work_item) { create(:work_item, :epic_with_legacy_epic, namespace: another_group) }

          # As a new work item is created, we need to recreate the parent_link
          let_it_be(:parent_link) do
            create(:parent_link, work_item: work_item, work_item_parent: epic.work_item,
              relative_position: 20).tap do |l|
              work_item.sync_object.update!(parent: epic, work_item_parent_link: l, relative_position: 20)
            end
          end

          before do
            stub_licensed_features(epics: true, subepics: true)
          end

          it "clears the parent_link from work_item and clears the parent from the epic sync object" do
            expect { callback.post_move_cleanup }.to change { work_item.reload.parent_link }.to(nil)
              .and change { work_item.reload.sync_object.parent }.to(nil)
          end

          it "deletes the parent_link but does not delete any epic_issue record as there is none" do
            expect { callback.post_move_cleanup }.to change { WorkItems::ParentLink.count }.by(-1)
              .and not_change { EpicIssue.count }
          end
        end
      end

      context 'when cleanup_data_source_work_item_data feature is disabled' do
        before do
          stub_feature_flags(cleanup_data_source_work_item_data: false)
        end

        context 'when work item to be moved is an issue with epic_issue record' do
          let_it_be(:parent_link) do
            create(:parent_link, work_item: work_item, work_item_parent: epic.work_item,
              relative_position: 20).tap do |l|
              create(:epic_issue, issue: work_item, epic: epic, work_item_parent_link: l, relative_position: 20)
            end
          end

          it "clears the epic and delete the epic_issue and the parent_link records" do
            expect { callback.post_move_cleanup }.to change { work_item.reload.epic }.from(epic).to(nil)
              .and change { EpicIssue.count }.by(-1)
              .and change { WorkItems::ParentLink.count }.by(-1)
          end
        end

        context "when work item to be moved is an epic" do
          let_it_be(:work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
          let_it_be(:target_work_item) { create(:work_item, :epic_with_legacy_epic, namespace: another_group) }

          # As a new work item is created, we need to recreate the parent_link
          let_it_be(:parent_link) do
            create(:parent_link, work_item: work_item, work_item_parent: epic.work_item,
              relative_position: 20).tap do |l|
              work_item.sync_object.update!(parent: epic, work_item_parent_link: l, relative_position: 20)
            end
          end

          before do
            stub_licensed_features(epics: true, subepics: true)
          end

          it "clears the parent_link from work_item but does not clear the parent from the epic sync object" do
            expect { callback.post_move_cleanup }.to change { work_item.reload.parent_link }.to(nil)
            .and change { work_item.reload.sync_object.parent }.to(nil)
          end

          it "deletes the parent_link but does not delete any epic_issue record as there is none" do
            expect { callback.post_move_cleanup }.to change { WorkItems::ParentLink.count }.by(-1)
              .and not_change { EpicIssue.count }
          end
        end
      end
    end
  end
end
