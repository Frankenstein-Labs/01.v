# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Bulk update work items', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:developer) { create(:user) }
  let_it_be(:private_group) { create(:group, :private) }
  let_it_be(:parent_group) { create(:group, developers: developer) }
  let_it_be(:group) { create(:group, parent: parent_group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:label1) { create(:group_label, group: parent_group) }
  let_it_be(:label2) { create(:group_label, group: parent_group) }
  let_it_be(:label3) { create(:group_label, group: private_group) }
  let_it_be(:iteration) { create(:iteration) }
  let_it_be_with_reload(:work_item1) { create(:work_item, :group_level, namespace: group, labels: [label1]) }
  let_it_be_with_reload(:work_item2) do
    create(:work_item, project: project, labels: [label1], health_status: :at_risk, iteration: iteration)
  end

  let_it_be_with_reload(:work_item3) { create(:work_item, :group_level, namespace: parent_group, labels: [label1]) }
  let_it_be_with_reload(:work_item4) { create(:work_item, :group_level, namespace: private_group, labels: [label3]) }
  let_it_be_with_reload(:epic) { create(:work_item, :epic, namespace: group, labels: [label1]) }

  let(:mutation) { graphql_mutation(:work_item_bulk_update, base_arguments.merge(widget_arguments)) }
  let(:mutation_response) { graphql_mutation_response(:work_item_bulk_update) }
  let(:current_user) { developer }
  let(:work_item_ids) do
    [work_item1, work_item2, work_item3, work_item4, epic].map do |work_item|
      work_item.to_gid.to_s
    end
  end

  let(:base_arguments) { { full_path: parent.full_path.to_s, ids: work_item_ids } }

  let(:widget_arguments) do
    {
      labels_widget: {
        add_label_ids: [label2.to_gid.to_s],
        remove_label_ids: [label1.to_gid.to_s, label3.to_gid.to_s]
      }
    }
  end

  context 'when user can update all issues' do
    context 'when scoping to a parent group' do
      let(:parent) { group }

      context 'when group_bulk_edit feature is available' do
        before do
          stub_licensed_features(epics: true, group_bulk_edit: true)
        end

        it 'updates only specified work items that belong to the group hierarchy' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.to change { work_item1.reload.label_ids }.from([label1.id]).to([label2.id])
            .and change { work_item2.reload.label_ids }.from([label1.id]).to([label2.id])
            .and change { epic.reload.label_ids }.from([label1.id]).to([label2.id])
            .and not_change { work_item3.reload.label_ids }.from([label1.id])
            .and not_change { work_item4.reload.label_ids }.from([label3.id])

          expect(mutation_response).to include(
            'updatedWorkItemCount' => 3
          )
        end

        context 'when current user cannot read the specified group' do
          let(:parent) { private_group }

          it 'returns a resource not found error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect_graphql_errors_to_include(
              "The resource that you are attempting to access does not exist or you don't have " \
                'permission to perform this action'
            )
          end
        end

        context 'when updating confidentiality' do
          let(:widget_arguments) do
            {
              confidential: true
            }
          end

          it 'updates confidentiality for work items in the group hierarchy' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { work_item1.reload.confidential }.from(false).to(true)
              .and change { work_item2.reload.confidential }.from(false).to(true)
              .and change { epic.reload.confidential }.from(false).to(true)
              .and not_change { work_item3.reload.confidential }.from(false)
              .and not_change { work_item4.reload.confidential }.from(false)

            expect(mutation_response).to include(
              'updatedWorkItemCount' => 3
            )
          end

          context 'when epic has non-confidential children' do
            let_it_be(:child_issue) { create(:work_item, project: project, confidential: false) }

            before do
              create(:parent_link, work_item_parent: epic, work_item: child_issue)
            end

            it 'does not update the epic confidentiality and continues with other work items' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
              end.to change { work_item1.reload.confidential }.from(false).to(true)
                .and change { work_item2.reload.confidential }.from(false).to(true)
                .and not_change { epic.reload.confidential }.from(false) # Epic fails to update
                .and not_change { work_item3.reload.confidential }.from(false)
                .and not_change { work_item4.reload.confidential }.from(false)

              expect(mutation_response).to include(
                'updatedWorkItemCount' => 2 # Only 2 items updated instead of 3
              )
            end
          end
        end

        context 'when updating status' do
          let(:widget_arguments) do
            {
              'stateEvent' => 'CLOSE'
            }
          end

          it 'closes all work items' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { work_item1.reload.state }.from("opened").to("closed")
                .and change { work_item2.reload.state }.from("opened").to("closed")
                .and change { epic.reload.state }.from("opened").to("closed")
                .and not_change { work_item3.reload.state }.from("opened")
                .and not_change { work_item4.reload.state }.from("opened")

            expect(mutation_response).to include(
              'updatedWorkItemCount' => 3
            )
          end
        end

        context "when updating subscription" do
          let(:widget_arguments) do
            {
              'subscriptionEvent' => 'SUBSCRIBE'
            }
          end

          it 'subscribes current user to all work items in the group hierarchy' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { work_item1.subscriptions.where(user: current_user, subscribed: true).count }.by(1)
              .and change { work_item2.subscriptions.where(user: current_user, subscribed: true).count }.by(1)
              .and change { epic.subscriptions.where(user: current_user, subscribed: true).count }.by(1)

            expect(mutation_response).to include(
              'updatedWorkItemCount' => 3
            )

            expect(work_item3.reload.subscriptions.where(user: current_user, subscribed: true)).not_to exist
            expect(work_item4.reload.subscriptions.where(user: current_user, subscribed: true)).not_to exist
          end

          context 'when unsubscribing' do
            before do
              work_item1.subscribe(current_user, project)
              work_item2.subscribe(current_user, project)
              epic.subscribe(current_user, project)
            end

            let(:widget_arguments) do
              {
                'subscriptionEvent' => 'UNSUBSCRIBE'
              }
            end

            it 'unsubscribes current user from all work items in the group hierarchy' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
              end.to change {
                       work_item1.subscriptions.where(user: current_user, subscribed: true).exists?
                     }.from(true).to(false)
                .and change {
                       work_item2.subscriptions.where(user: current_user, subscribed: true).exists?
                     }.from(true).to(false)
                .and change {
                       epic.subscriptions.where(user: current_user, subscribed: true).exists?
                     }.from(true).to(false)

              expect(mutation_response).to include(
                'updatedWorkItemCount' => 3
              )

              # Verify that work items outside the group hierarchy are not affected
              expect(work_item3.reload.subscriptions.where(user: current_user, subscribed: true)).not_to exist
              expect(work_item4.reload.subscriptions.where(user: current_user, subscribed: true)).not_to exist
            end
          end
        end

        context 'when updating assignees widget' do
          let_it_be(:assignee1) { create(:user, developer_of: group) }
          let_it_be(:assignee2) { create(:user, developer_of: group) }

          let(:widget_arguments) do
            {
              assignees_widget: {
                assignee_ids: [assignee1.to_gid.to_s, assignee2.to_gid.to_s]
              }
            }
          end

          it 'updates assignees for work items in the group hierarchy' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { work_item1.reload.assignee_ids.sort }.from([]).to([assignee1.id, assignee2.id])
              .and change { work_item2.reload.assignee_ids.sort }.from([]).to([assignee1.id, assignee2.id])
              .and change { epic.reload.assignee_ids.sort }.from([]).to([assignee1.id, assignee2.id])
              .and not_change { work_item3.reload.assignee_ids }.from([])
              .and not_change { work_item4.reload.assignee_ids }.from([])

            expect(mutation_response).to include(
              'updatedWorkItemCount' => 3
            )
          end
        end

        context 'when updating milestone widget' do
          let_it_be(:group_milestone) { create(:milestone, group: group) }

          let(:widget_arguments) do
            {
              milestone_widget: {
                milestone_id: group_milestone.to_gid.to_s
              }
            }
          end

          it 'updates milestone for work items in the group hierarchy' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { work_item1.reload.milestone_id }.from(nil).to(group_milestone.id)
              .and change { work_item2.reload.milestone_id }.from(nil).to(group_milestone.id)
              .and change { epic.reload.milestone_id }.from(nil).to(group_milestone.id)
              .and not_change { work_item3.reload.milestone_id }.from(nil)
              .and not_change { work_item4.reload.milestone_id }.from(nil)

            expect(mutation_response).to include(
              'updatedWorkItemCount' => 3
            )
          end
        end
      end

      context 'when group_bulk_edit feature is not available' do
        before do
          stub_licensed_features(epics: true, group_bulk_edit: false)
        end

        it 'returns a licensed feature not available message' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect_graphql_errors_to_include(
            _('Group work item bulk edit is a licensed feature not available for this group.')
          )
        end
      end

      context 'when updating parent' do
        before do
          stub_licensed_features(group_bulk_edit: true)
        end

        context 'when epics are enabled' do
          before do
            stub_licensed_features(epics: true)
          end

          context 'when the parent is a valid target for the work item' do
            let_it_be(:parent_work_item) { create(:work_item, :epic, :group_level, namespace: group) }
            let(:widget_arguments) { { hierarchy_widget: { parent_id: parent_work_item.to_gid } } }

            it 'sets the parent of the work item' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
              end.to change { work_item1.reload.work_item_parent }.from(nil).to(parent_work_item)
                .and change { work_item2.reload.work_item_parent }.from(nil).to(parent_work_item)
            end
          end

          context 'when the parent type is incompatible with the work item' do
            let_it_be(:parent_work_item) { create(:work_item, :task, project: project) }
            let(:widget_arguments) { { hierarchy_widget: { parent_id: parent_work_item.to_gid } } }

            it 'does not set the parent of the work item' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
              end.to not_change { work_item1.reload.work_item_parent }.from(nil)
                .and not_change { work_item2.reload.work_item_parent }.from(nil)
            end
          end
        end

        context 'when epics are disabled' do
          before do
            stub_licensed_features(epics: false)
          end

          let_it_be(:parent_work_item) { create(:work_item, :epic, :group_level, namespace: group) }
          let(:widget_arguments) { { hierarchy_widget: { parent_id: parent_work_item.to_gid } } }

          it 'does not set the parent of the work item' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to not_change { work_item1.reload.work_item_parent }.from(nil)
              .and not_change { work_item2.reload.work_item_parent }.from(nil)
          end
        end
      end

      context 'when updating health status' do
        let(:widget_arguments) { { health_status_widget: { health_status: :onTrack } } }

        context 'when issuable_health_status feature is disabled' do
          before do
            stub_licensed_features(epics: true, group_bulk_edit: true, issuable_health_status: false)
          end

          it 'does not set the health status of the related work items' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to not_change { work_item1.reload.health_status }.and not_change { work_item2.reload.health_status }
          end
        end

        context 'when issuable_health_status feature is enabled' do
          before do
            stub_licensed_features(epics: true, group_bulk_edit: true, issuable_health_status: true)
          end

          it 'sets the health status of the related work items' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { work_item1.reload.health_status }.from(nil).to('on_track')
              .and change { work_item2.reload.health_status }.from('at_risk').to('on_track')
          end

          context 'when the work item type does not support health_status' do
            # Tasks do not support health status
            let_it_be(:task_work_item) { create(:work_item, :task, project: project) }
            let(:work_item_ids) { [task_work_item.to_gid.to_s] }

            it 'does not set the health status and fails gracefully' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
              end.not_to change { task_work_item.reload.health_status }

              expect_graphql_errors_to_be_empty
            end
          end
        end
      end

      context 'when updating iteration' do
        let(:new_iteration) { create(:iteration, group: group) }
        let(:widget_arguments) { { iteration_widget: { iteration_id: new_iteration.to_gid } } }

        context 'when iterations feature is disabled' do
          before do
            stub_licensed_features(epics: true, group_bulk_edit: true, iterations: false)
          end

          it 'does not set the iteration of the related work items' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to not_change { work_item1.reload.iteration }.and not_change { work_item2.reload.iteration }
          end
        end

        context 'when iterations feature is enabled' do
          before do
            stub_licensed_features(epics: true, group_bulk_edit: true, iterations: true)
          end

          it 'sets the iteration of the related work items' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { work_item1.reload.iteration }.from(nil).to(new_iteration)
              .and change { work_item2.reload.iteration }.from(iteration).to(new_iteration)
          end
        end
      end

      context 'when updating status' do
        let(:system_defined_done_status) { build(:work_item_system_defined_status, :done) }
        let(:status) { system_defined_done_status }

        let(:work_item_ids) do
          [work_item1, work_item2, work_item3, work_item4].map do |work_item|
            work_item.to_gid.to_s
          end
        end

        let(:widget_arguments) { { status_widget: { status: status.to_gid } } }

        shared_examples 'updates work item statuses' do |expected_count|
          it 'sets the status of the related work items' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { work_item1.reload.current_status&.status }.from(nil).to(status)
              .and change { work_item2.reload.current_status&.status }.from(nil).to(status)
              .and not_change { work_item3.reload.current_status&.status }
              .and not_change { work_item4.reload.current_status&.status }

            expect(mutation_response).to include(
              'updatedWorkItemCount' => expected_count
            )
          end
        end

        shared_examples 'does not update work item statuses' do
          it 'does not set the status of the related work items' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to not_change { work_item1.reload.current_status&.status }
              .and not_change { work_item2.reload.current_status&.status }
          end
        end

        context 'when work_item_status feature is enabled' do
          before do
            stub_licensed_features(epics: true, group_bulk_edit: true, work_item_status: true)
          end

          context 'with system-defined lifecycle' do
            context 'with system-defined status' do
              it_behaves_like 'updates work item statuses', 2
            end

            context 'with custom status' do
              let(:custom_done_status) { create(:work_item_custom_status, :done, namespace: parent_group) }
              let(:status) { custom_done_status }

              it_behaves_like 'does not update work item statuses'
            end
          end

          context 'with custom lifecycle' do
            let(:lifecycle) { create(:work_item_custom_lifecycle, namespace: parent_group) }

            let!(:type_custom_lifecycle) do
              create(:work_item_type_custom_lifecycle,
                lifecycle: lifecycle,
                work_item_type: work_item1.work_item_type,
                namespace: parent_group
              )
            end

            context 'with custom status' do
              let(:status) { lifecycle.default_closed_status }

              it_behaves_like 'updates work item statuses', 2
            end

            context 'with system-defined status' do
              it 'updates work items with default statuses' do
                expect do
                  post_graphql_mutation(mutation, current_user: current_user)
                end.to change { work_item1.reload.current_status&.status }.from(nil).to(lifecycle.default_open_status)
                  .and change { work_item2.reload.current_status&.status }.from(nil).to(lifecycle.default_open_status)
                  .and not_change { work_item3.reload.current_status&.status }
                  .and not_change { work_item4.reload.current_status&.status }

                expect(mutation_response).to include('updatedWorkItemCount' => 2)
              end
            end
          end

          context 'when work item type does not support status' do
            let(:work_item_ids) { [epic.to_gid.to_s] }

            it 'does not set the status and fails gracefully' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
              end.not_to change { epic.reload.current_status&.status }

              expect_graphql_errors_to_be_empty
            end
          end
        end

        context 'when work_item_status feature is disabled' do
          before do
            stub_licensed_features(epics: true, group_bulk_edit: true, work_item_status: false)
          end

          it_behaves_like 'does not update work item statuses'
        end
      end
    end

    context 'when scoping to a project' do
      let(:base_arguments) { { full_path: project.full_path, ids: work_item_ids } }

      it 'updates work items' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to not_change { work_item1.reload.label_ids }.from([label1.id])
          .and change { work_item2.reload.label_ids }.from([label1.id]).to([label2.id])
          .and not_change { epic.reload.label_ids }.from([label1.id])
          .and not_change { work_item3.reload.label_ids }.from([label1.id])
          .and not_change { work_item4.reload.label_ids }.from([label3.id])

        expect(mutation_response).to include('updatedWorkItemCount' => 1)
      end
    end
  end
end
