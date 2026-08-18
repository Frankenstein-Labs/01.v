# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::UpdateService, feature_category: :team_planning do
  let_it_be(:developer) { create(:user) }
  let_it_be(:group) { create(:group, developers: developer) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:issue_work_item_type) { build(:work_item_system_defined_type, :issue) }
  let_it_be(:task_work_item_type) { build(:work_item_system_defined_type, :task) }
  let_it_be(:incident_work_item_type) { build(:work_item_system_defined_type, :incident) }
  let_it_be_with_refind(:work_item) { create(:work_item, project: project) }

  let_it_be(:current_user) { developer }
  let(:widget_params) { {} }
  let(:params) { {} }

  describe '#execute' do
    let(:service) do
      described_class.new(
        container: project,
        current_user: current_user,
        params: params,
        widget_params: widget_params
      )
    end

    subject(:update_work_item) { service.execute(work_item) }

    before do
      stub_licensed_features(epics: true)
    end

    it_behaves_like 'work item widgetable service' do
      let(:widget_params) do
        {
          weight_widget: { weight: 1 }
        }
      end

      let(:service_execute) { subject }

      let(:supported_widgets) do
        [
          {
            klass: WorkItems::Callbacks::Weight,
            callback: :before_update
          }
        ]
      end
    end

    context 'when updating widgets' do
      context 'for the progress widget' do
        let(:objective_type) { build(:work_item_system_defined_type, :objective) }

        let(:widget_params) { { progress_widget: { progress: 50 } } }

        before do
          stub_licensed_features(epics: true, okrs: true)

          work_item.update!(work_item_type: objective_type)
        end

        it_behaves_like 'update service that triggers GraphQL work_item_updated subscription' do
          subject(:execute_service) { update_work_item }
        end
      end

      context 'for the weight widget' do
        let(:widget_params) { { weight_widget: { weight: new_weight } } }

        before do
          stub_licensed_features(epics: true, issue_weights: true)

          work_item.update!(weight: 1)
        end

        context 'when weight is changed' do
          let(:new_weight) { nil }

          it "triggers 'issuableWeightUpdated' for issuable weight update subscription" do
            expect(GraphqlTriggers).to receive(:issuable_weight_updated).with(work_item).and_call_original

            subject
          end

          it_behaves_like 'update service that triggers GraphQL work_item_updated subscription' do
            subject(:execute_service) { update_work_item }
          end
        end

        context 'when weight remains unchanged' do
          let(:new_weight) { 1 }

          it "does not trigger 'issuableWeightUpdated' for issuable weight update subscription" do
            expect(GraphqlTriggers).not_to receive(:issuable_weight_updated)

            subject
          end
        end

        context 'when weight widget param is not provided' do
          let(:widget_params) { {} }

          it "does not trigger 'issuableWeightUpdated' for issuable weight update subscription" do
            expect(GraphqlTriggers).not_to receive(:issuable_weight_updated)

            subject
          end
        end
      end

      context 'for the iteration widget' do
        let_it_be(:cadence) { create(:iterations_cadence, group: group) }
        let_it_be(:iteration) { create(:iteration, iterations_cadence: cadence) }

        let(:widget_params) { { iteration_widget: { iteration: new_iteration } } }

        before do
          stub_licensed_features(epics: true, iterations: true)

          work_item.update!(iteration: nil)
        end

        context 'when iteration is changed' do
          let(:new_iteration) { iteration }

          it "triggers 'issuableIterationUpdated' for issuable iteration update subscription" do
            expect(GraphqlTriggers).to receive(:issuable_iteration_updated).with(work_item).and_call_original

            subject
          end
        end

        context 'when iteration remains unchanged' do
          let(:new_iteration) { nil }

          it "does not trigger 'issuableIterationUpdated' for issuable iteration update subscription" do
            expect(GraphqlTriggers).not_to receive(:issuable_iteration_updated)

            subject
          end
        end

        context 'when iteration widget param is not provided' do
          let(:widget_params) { {} }

          it "does not trigger 'issuableIterationUpdated' for issuable iteration update subscription" do
            expect(GraphqlTriggers).not_to receive(:issuable_iteration_updated)

            subject
          end
        end
      end

      context 'for the health_status widget' do
        let(:widget_params) { { health_status_widget: { health_status: new_health_status } } }

        before do
          stub_licensed_features(epics: true, issuable_health_status: true)

          work_item.update!(health_status: :needs_attention)
        end

        context 'when health_status is changed' do
          let(:new_health_status) { :on_track }

          it "triggers 'issuableHealthStatusUpdated' subscription" do
            expect(GraphqlTriggers).to receive(:issuable_health_status_updated).with(work_item).and_call_original

            subject
          end
        end

        context 'when health_status remains unchanged' do
          let(:new_health_status) { :needs_attention }

          it "does not trigger 'issuableHealthStatusUpdated' subscription" do
            expect(GraphqlTriggers).not_to receive(:issuable_health_status_updated)

            subject
          end
        end

        context 'when health_status widget param is not provided' do
          let(:widget_params) { {} }

          it "does not trigger 'issuableHealthStatusUpdated' subscription" do
            expect(GraphqlTriggers).not_to receive(:issuable_health_status_updated)

            subject
          end
        end
      end

      context 'for color widget' do
        let_it_be_with_refind(:work_item) { create(:work_item, :epic, namespace: group) }
        let_it_be(:default_color) { '#1068bf' }

        let(:new_color) { '#c91c00' }

        before do
          stub_licensed_features(epics: true, epic_colors: true)
        end

        context 'when work item has a color' do
          let_it_be(:existing_color) { create(:color, work_item: work_item, color: '#0052cc') }

          context 'when color changes' do
            let(:widget_params) { { color_widget: { color: new_color } } }

            it 'updates existing color' do
              expect { subject }.not_to change { WorkItems::Color.count }

              expect(work_item.color.color.to_s).to eq(new_color)
              expect(work_item.color.issue_id).to eq(work_item.id)
            end

            it 'creates system notes' do
              expect(SystemNoteService).to receive(:change_color_note)
               .with(work_item, current_user, existing_color.color.to_s)
               .and_call_original

              expect { subject }.to change { Note.count }.by(1)
              expect(work_item.notes.last.note).to eq(
                "changed color from `#{existing_color.color}` **Custom** to `#{new_color}` **Dark red**"
              )
            end
          end

          context 'when color remains unchanged' do
            let(:widget_params) { {} }

            it 'does not update color' do
              expect { subject }.to not_change { WorkItems::Color.count }.and not_change { Note.count }
              expect(work_item.color.color.to_s).to eq(existing_color.color.to_s)
            end
          end

          context 'when color param is the same as the work item color' do
            let(:widget_params) { { color_widget: { color: existing_color.color.to_s } } }

            it 'does not update color' do
              expect { subject }.to not_change { WorkItems::Color.count }.and not_change { Note.count }
            end
          end

          context 'when widget is not supported in the new type' do
            let(:widget_params) { { color_widget: { color: new_color } } }

            before do
              allow_next_instance_of(WorkItems::Callbacks::Color) do |instance|
                allow(instance).to receive(:excluded_in_new_type?).and_return(true)
              end
            end

            it 'removes color' do
              expect { subject }.to change { work_item.reload.color }.from(existing_color).to(nil)
            end

            it 'creates system notes' do
              expect(SystemNoteService).to receive(:change_color_note)
                .with(work_item, current_user, nil)
                .and_call_original

              expect { subject }.to change { Note.count }.by(1)
              expect(Note.last.note).to eq("removed color `#{existing_color.color}` **Custom**")
            end
          end
        end

        context 'when work item has no color' do
          let(:widget_params) { { color_widget: { color: new_color } } }

          it 'creates a new color record' do
            expect { subject }.to change { WorkItems::Color.count }.by(1)

            expect(work_item.color.color.to_s).to eq(new_color)
            expect(work_item.color.issue_id).to eq(work_item.id)
          end

          it 'creates system notes' do
            expect(SystemNoteService).to receive(:change_color_note)
              .with(work_item, current_user, nil)
              .and_call_original

            expect { subject }.to change { Note.count }.by(1)
            expect(work_item.notes.last.note).to eq("set color to `#{new_color}` **Dark red**")
          end
        end
      end

      context 'for dates widget' do
        let_it_be(:fixed_start) { 1.week.ago.to_date }
        let_it_be(:fixed_due) { 1.week.from_now.to_date }

        let_it_be_with_refind(:work_item) do
          create(:work_item, :epic_with_legacy_epic, namespace: group).tap do |wi|
            wi.synced_epic.update!(start_date_fixed: fixed_start, due_date_fixed: fixed_due)
          end
        end

        let_it_be_with_refind(:dates_source) do
          create(
            :work_items_dates_source,
            work_item: work_item,
            start_date_fixed: fixed_start,
            due_date_fixed: fixed_due
          )
        end

        context 'when widget params are present' do
          shared_examples 'toggle dates' do |fixed:|
            let_it_be(:from_condition) { !fixed }
            let_it_be(:from_start_date) { fixed ? nil : fixed_start }
            let_it_be(:to_start_date) { fixed ? fixed_start : nil }
            let_it_be(:from_due_date) { fixed ? nil : fixed_due }
            let_it_be(:to_due_date) { fixed ? fixed_due : nil }

            let(:widget_params) do
              { start_and_due_date_widget: { is_fixed: fixed } }
            end

            before do
              work_item.synced_epic.update!(
                start_date: from_start_date,
                end_date: from_due_date,
                start_date_is_fixed: from_condition,
                due_date_is_fixed: from_condition
              )

              dates_source.update!(
                start_date: from_start_date,
                due_date: from_due_date,
                due_date_is_fixed: from_condition,
                start_date_is_fixed: from_condition
              )
            end

            it 'updates dates', :aggregate_failures do
              expect(WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService)
                .to receive(:new)
                .with(WorkItem.id_in(work_item))
                .and_call_original

              expect { subject }
                .to change { work_item.reload.dates_source.start_date }.from(from_start_date).to(to_start_date)
                .and change { work_item.start_date }.from(from_start_date).to(to_start_date)
                .and change { work_item.synced_epic.reload.start_date }.from(from_start_date).to(to_start_date)
                .and change { work_item.dates_source.start_date_is_fixed }.from(from_condition).to(fixed)
                .and change { work_item.dates_source.due_date }.from(from_due_date).to(to_due_date)
                .and change { work_item.due_date }.from(from_due_date).to(to_due_date)
                .and change { work_item.synced_epic.end_date }.from(from_due_date).to(to_due_date)
                .and change { work_item.dates_source.due_date_is_fixed }.from(from_condition).to(fixed)
            end
          end

          it_behaves_like 'toggle dates', fixed: true
          it_behaves_like 'toggle dates', fixed: false
        end

        context 'when widget params are not present' do
          let(:widget_params) { { start_and_due_date_widget: {} } }

          it 'does not update rolledup dates' do
            expect(WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService)
              .not_to receive(:new)

            expect { subject }.not_to change { WorkItems::DatesSource.count }
          end
        end
      end

      context 'for custom statuses widget' do
        let_it_be_with_refind(:work_item) { create(:work_item, :task, project: project) }
        let(:status) { build(:work_item_system_defined_status, :to_do) }

        before do
          stub_licensed_features(work_item_status: true)
        end

        context "with status widget params" do
          let(:widget_params) { { status_widget: { status: status } } }

          it 'creates a new current status record' do
            expect { update_work_item }.to change { WorkItems::Statuses::CurrentStatus.count }.by(1)
          end

          it 'reports status_widget to the work_item_updated trigger' do
            expect(GraphqlTriggers).to receive(:work_item_updated).with(
              work_item, updated_changes: include('status_widget')
            ).and_call_original

            update_work_item
          end

          context "when state and status params are both present" do
            before do
              params[:state_event] = "close"
            end

            it 'returns an error' do
              expect(update_work_item[:status]).to eq(:error)
              expect(update_work_item[:message])
                .to eq('State event and status widget cannot be changed at the same time')
            end
          end
        end

        context "without status widget params" do
          let(:widget_params) { {} }

          it 'creates a new current status record' do
            expect { update_work_item }.not_to change { WorkItems::Statuses::CurrentStatus.count }
          end
        end
      end
    end

    context 'with a synced epic' do
      let_it_be_with_refind(:work_item) do
        create(:work_item, :epic_with_legacy_epic, namespace: group, updated_by: create(:user))
      end

      let_it_be(:epic) { work_item.synced_epic }
      let(:start_date) { (Time.current + 1.day).to_date }
      let(:due_date) { (Time.current + 2.days).to_date }

      let(:service) do
        described_class.new(
          container: group,
          current_user: current_user,
          params: params,
          widget_params: widget_params
        )
      end

      let(:widget_params) do
        {
          description_widget: {
            description: 'new description'
          },
          color_widget: {
            color: '#FF0000'
          },
          start_and_due_date_widget: { start_date: start_date, due_date: due_date }
        }
      end

      let(:params) do
        {
          confidential: true,
          title: 'new title'
        }
      end

      before_all do
        group.add_developer(developer)
      end

      before do
        stub_licensed_features(epics: true, subepics: true, epic_colors: true)
      end

      subject(:execute) { update_work_item }

      it_behaves_like 'syncs all data from a work_item to an epic'

      context 'when only providing title and description' do
        let(:widget_params) do
          {
            description_widget: {
              description: 'new description'
            }
          }
        end

        it_behaves_like 'syncs all data from a work_item to an epic'

        context 'and description version created for work item only' do
          before do
            work_item.update_columns(description: "some older description")
            work_item.sync_object.update_columns(description: "some older description")
          end

          it 'creates description version on epic work item only' do
            subject

            expect(work_item.reload.own_description_versions.count).to eq(2)
            expect(work_item.sync_object.reload.own_description_versions.count).to eq(0)
          end
        end
      end

      it 'syncs the data to the epic', :aggregate_failures do
        update_work_item

        expect(epic.reload.title).to eq('new title')
        expect(work_item.reload.title).to eq('new title')
        expect(epic.title_html).to eq(work_item.title_html)

        expect(epic.last_edited_by).to eq(current_user)

        expect(epic.updated_at).to eq(work_item.updated_at)

        expect(epic.description).to eq('new description')
        expect(work_item.description).to eq('new description')
        expect(epic.description_html).to eq(work_item.description_html)

        expect(epic.reload.confidential).to be(true)
        expect(work_item.confidential).to be(true)

        expect(work_item.color.color.to_s).to eq('#FF0000')
        expect(epic.color.to_s).to eq('#FF0000')

        expect(work_item.start_date).to eq(start_date)
        expect(work_item.due_date).to eq(due_date)

        expect(epic.start_date).to eq(start_date)
        expect(epic.due_date).to eq(due_date)
      end

      context 'when updating labels' do
        let_it_be(:label1) { create(:group_label, group: group) }
        let_it_be(:label2) { create(:group_label, group: group) }
        let_it_be(:new_labels) { create_list(:group_label, 2, group: group) }

        let(:labels_widget) { {} }
        let(:labels_params) { {} }
        let(:service) do
          described_class.new(
            container: group,
            current_user: current_user,
            params: params.merge(labels_params),
            widget_params: widget_params.merge(labels_widget)
          )
        end

        before do
          epic.labels << label1
          epic.work_item.labels << label2
        end

        context 'and replacing labels with `label_ids` param' do
          let(:labels_params) { { label_ids: new_labels.map(&:id) } }
          let(:expected_labels) { new_labels }

          it_behaves_like 'syncs labels between epics and epic work items'
        end

        context 'and adding and removing labels through params' do
          context 'and removing label assigned to epic' do
            let(:labels_params) { { add_label_ids: new_labels.map(&:id), remove_label_ids: [label1.id] } }
            let(:expected_labels) { [new_labels, label2].flatten }

            it_behaves_like 'syncs labels between epics and epic work items'
          end

          context 'and removing label assigned to epic work item' do
            let(:labels_params) do
              { add_label_ids: new_labels.map(&:id), remove_label_ids: [label2.id] }
            end

            let(:expected_labels) { [new_labels, label1].flatten }

            it_behaves_like 'syncs labels between epics and epic work items'
          end
        end

        context 'and adding and removing labels through widget params' do
          context 'and removing label assigned to epic' do
            let(:labels_widget) do
              { labels_widget: { add_label_ids: new_labels.map(&:id), remove_label_ids: [label1.id] } }
            end

            let(:expected_labels) { [new_labels, label2].flatten }

            it_behaves_like 'syncs labels between epics and epic work items'
          end

          context 'and removing label assigned to epic work item' do
            let(:labels_widget) do
              {
                labels_widget: {
                  add_label_ids: new_labels.map(&:id), remove_label_ids: [label2.id]
                }
              }
            end

            let(:expected_labels) { [new_labels, label1].flatten }

            it_behaves_like 'syncs labels between epics and epic work items'
          end
        end
      end

      context 'when updating the work item fails' do
        before do
          allow_next_found_instance_of(WorkItem) do |work_item|
            allow(work_item).to receive(:update).and_return(false)
          end
        end

        it 'does not update the epic or work item' do
          expect { execute }
            .to not_change { work_item.reload }
            .and not_change { epic.reload }
        end
      end

      context 'when updating the epic fails' do
        before do
          allow_next_found_instance_of(Epic) do |epic|
            allow(epic).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new)
          end
        end

        it 'does not update the work item' do
          expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
            .with({
              message: "Not able to update epic",
              error_message: "Record invalid",
              group_id: group.id,
              work_item_id: work_item.id
            })

          expect { execute }
            .to not_change { work_item.reload }
            .and not_change { epic.reload }
            .and raise_error(ActiveRecord::RecordInvalid)
        end
      end

      context 'when changes are invalid' do
        let(:widget_params) { {} }
        let(:params) { { title: '' } }

        it 'does not propagate them to the epic' do
          expect { execute }
            .to not_change { work_item.reload.title }
            .and not_change { epic.reload.title }
        end
      end

      context 'when work item has no synced epic' do
        let_it_be_with_refind(:work_item) { create(:work_item, :epic, namespace: group) }

        it 'does not error and updates the work item' do
          expect { execute }.not_to raise_error

          expect(work_item.reload.title).to eq('new title')
        end
      end

      context 'when work item record is outdated' do
        let(:widget_params) { {} }
        let(:params) do
          {
            title: 'new title'
          }
        end

        context 'for base attributes' do
          before do
            epic.update!(confidential: true)
            work_item.update!(confidential: false)
          end

          it 'only syncs changed attributes' do
            expect { execute }
              .to change { epic.reload.title }
              .and not_change { epic.reload.confidential }
          end
        end

        context 'for color' do
          before do
            epic.update!(color: '#FF0000')
            work_item.build_color
            work_item.color.update!(color: '#00FF00')
          end

          it 'does not sync when color did not change as part of the request' do
            expect { execute }.to not_change { epic.reload.color.to_s }
          end
        end

        context 'for dates' do
          before do
            epic.update!(start_date: start_date, due_date: due_date)
            work_item.update!(start_date: start_date + 1.day, due_date: due_date + 1.day)
          end

          it 'does not sync when date did not change as part of the request' do
            expect { execute }.to not_change { epic.reload.start_date }.and not_change { epic.reload.due_date }
          end
        end

        context 'when handling changes with todos' do
          let_it_be(:todo) { create(:todo, target: epic, user: current_user) }

          let(:widget_params) do
            {
              description_widget: {
                description: 'new description'
              }
            }
          end

          it 'resolves todos for the synced epic when there are changes' do
            expect(TodoService).to receive(:new).twice.and_call_original
            expect_next_instance_of(TodoService) do |instance|
              expect(instance).to receive(:resolve_todos_for_target)
                 .with(epic, current_user).and_call_original
            end

            expect { execute }.to change { todo.reload.state }.from('pending').to('done')
          end

          context 'when there are no changes' do
            let(:widget_params) { {} }
            let(:params) { {} }

            it 'does not resolve todos' do
              expect(TodoService).not_to receive(:new)

              execute
            end
          end
        end

        context 'when updating tasks' do
          let_it_be_with_reload(:work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
          # `freeze: false` is required here: `epic` is derived from
          # `work_item.synced_epic` and is mutated (update!) during the example;
          # it cannot be independently reloaded. Keep the opt-out (see
          # gitlab-org/gitlab#602925).
          let_it_be(:epic, freeze: false) { work_item.synced_epic }

          let(:params) do
            {
              update_task: {
                line_source: '- [ ] Task item',
                line_sourcepos: '1:4-1:4',
                checked: true
              }
            }
          end

          let(:service) do
            described_class.new(
              container: group,
              current_user: current_user,
              params: params
            )
          end

          before do
            work_item.update!(description: "- [ ] Task item\n- [x] Completed task")
            epic.update!(description: "- [ ] Task item\n- [x] Completed task")
          end

          it 'updates both work item and epic description' do
            service.execute(work_item)
            expect(work_item.reload.description).to eq("- [x] Task item\n- [x] Completed task")
            expect(work_item.description).to eq(epic.reload.description)
          end
        end
      end
    end

    context 'when changing work_item_type' do
      let(:params) { { issue_type: 'task' } }

      context 'with system-defined lifecycle' do
        let_it_be(:lifecycle) { build(:work_item_system_defined_lifecycle) }

        it 'updates the work item type and preserves the status' do
          expect { update_work_item }
            .to change { work_item.reload.work_item_type }
            .from(issue_work_item_type).to(task_work_item_type)

          expect(work_item.reload.status_with_fallback).to eq(lifecycle.default_open_status)
        end

        it_behaves_like 'update service that triggers GraphQL work_item_updated subscription' do
          subject(:execute_service) { update_work_item }
        end
      end

      context 'when passing the legacy issue_type param in a namespace with a converted custom type' do
        # Regression coverage for the legacy fallback path. When the namespace has a custom type
        # that converts a system-defined base_type, looking up by base_type now returns the
        # converted custom type. The update service must route the assignment through
        # `work_item_type=` so that `persistable_id` writes the system-defined identifier
        # (the converted custom type's `converted_from_system_defined_type_identifier`) to the
        # work_item_type_id column, not the custom type's AR primary key.
        let_it_be(:converted_custom_type) do
          create(:work_item_custom_type, :converted_from_task, namespace: group)
        end

        let(:params) { { issue_type: 'task' } }

        before do
          stub_licensed_features(epics: true, configurable_work_item_types: true)
          stub_saas_features(namespace_scoped_work_item_types: true)
        end

        it 'resolves to the converted custom type and persists the system-defined id' do
          update_work_item

          work_item.reload
          expect(work_item.work_item_type).to eq(converted_custom_type)
          expect(work_item.work_item_type_id)
            .to eq(converted_custom_type.converted_from_system_defined_type_identifier)
        end
      end

      context 'when passing the new work_item_type param' do
        before do
          stub_licensed_features(epics: true, configurable_work_item_types: true)
          stub_saas_features(namespace_scoped_work_item_types: true)
        end

        context 'with custom types' do
          let_it_be(:custom_type) { create(:work_item_custom_type, namespace: group) }

          context 'when assigning a non-converted custom type' do
            let(:params) { { work_item_type: custom_type } }

            it 'assigns the custom work item type to the work item' do
              expect { update_work_item }
                .to change { work_item.reload.work_item_type }.from(issue_work_item_type).to(custom_type)
            end

            it 'creates a system note about the type change' do
              expect(SystemNoteService).to receive(:change_issue_type)
                .with(work_item, current_user)
                .and_call_original

              update_work_item
            end
          end

          context 'when assigning a custom type converted from a system-defined type' do
            let_it_be(:converted_custom_type) do
              create(:work_item_custom_type, :converted_from_task, namespace: group)
            end

            let(:params) { { work_item_type: converted_custom_type } }

            it 'persists the system-defined type id while still resolving to the custom type' do
              update_work_item

              work_item.reload
              expect(work_item.work_item_type).to eq(converted_custom_type)
              expect(work_item.work_item_type_id)
                .to eq(converted_custom_type.converted_from_system_defined_type_identifier)
            end
          end

          context 'when both work_item_type and issue_type are passed' do
            # The old issue_type-based lookup would resolve `issue_type: 'issue'` to the system-defined
            # Issue type and overwrite the custom type. With the new path, work_item_type wins.
            let(:params) { { work_item_type: custom_type, issue_type: 'issue' } }

            it 'prefers work_item_type over issue_type' do
              expect { update_work_item }
                .to change { work_item.reload.work_item_type }.from(issue_work_item_type).to(custom_type)
            end
          end
        end

        context 'with a system-defined type' do
          let(:params) { { work_item_type: task_work_item_type } }

          it 'updates the work item to the system-defined type' do
            expect { update_work_item }
              .to change { work_item.reload.work_item_type }
              .from(issue_work_item_type).to(task_work_item_type)
          end
        end

        context 'when work_item_type matches the current type' do
          let(:params) { { work_item_type: issue_work_item_type } }

          it 'does not change the work item type' do
            expect { update_work_item }.not_to change { work_item.reload.work_item_type_id }
          end

          it 'does not create a type change system note' do
            expect(SystemNoteService).not_to receive(:change_issue_type)

            update_work_item
          end
        end
      end

      context 'with custom lifecycles' do
        let_it_be(:lifecycle) { create(:work_item_custom_lifecycle, namespace: group) }

        before do
          stub_licensed_features(work_item_status: true)
        end

        context 'when old and new work item types share the same lifecycle' do
          let!(:issue_type_custom_lifecycle) do
            create(:work_item_type_custom_lifecycle,
              work_item_type: issue_work_item_type, lifecycle: lifecycle, namespace: group
            )
          end

          let!(:task_type_custom_lifecycle) do
            create(:work_item_type_custom_lifecycle,
              work_item_type: task_work_item_type, lifecycle: lifecycle, namespace: group
            )
          end

          it 'updates the work item type and preserves the status' do
            expect { update_work_item }
              .to change { work_item.reload.work_item_type }
              .from(issue_work_item_type).to(task_work_item_type)

            expect(work_item.reload.status_with_fallback).to eq(lifecycle.default_open_status)
          end

          it_behaves_like 'update service that triggers GraphQL work_item_updated subscription' do
            subject(:execute_service) { update_work_item }
          end
        end

        context 'when old and new work item types have different lifecycles' do
          let_it_be_with_reload(:lifecycle_2) { create(:work_item_custom_lifecycle, namespace: group) }

          let!(:issue_type_custom_lifecycle) do
            create(:work_item_type_custom_lifecycle,
              work_item_type: issue_work_item_type, lifecycle: lifecycle, namespace: group
            )
          end

          let!(:task_type_custom_lifecycle) do
            create(:work_item_type_custom_lifecycle,
              work_item_type: task_work_item_type, lifecycle: lifecycle_2, namespace: group
            )
          end

          it 'updates the work item type and sets the default status' do
            expect { update_work_item }
              .to change { work_item.reload.work_item_type }
              .from(issue_work_item_type).to(task_work_item_type)
              .and change { work_item.status_with_fallback }
              .from(lifecycle.default_open_status).to(lifecycle_2.default_open_status)
          end

          it_behaves_like 'update service that triggers GraphQL work_item_updated subscription' do
            subject(:execute_service) { update_work_item }
          end

          context 'with status mapping between issue default open and a previous task status' do
            let_it_be_with_reload(:custom_status) do
              create(:work_item_custom_status, :to_do, name: "Custom to do", namespace: group)
            end

            let_it_be(:custom_mapping) do
              create(
                :work_item_custom_status_mapping, namespace: group, work_item_type: issue_work_item_type,
                old_status: custom_status, new_status: lifecycle.default_open_status
              )
            end

            before do
              lifecycle_2.statuses << custom_status
              lifecycle_2.save!
              work_item.update!(work_item_type: task_work_item_type)
              create(
                :work_item_current_status, work_item: work_item, custom_status: custom_status, updated_at: 2.days.ago
              )
            end

            it 'sets the statuses to correct defaults' do
              described_class.new(
                container: project,
                current_user: current_user,
                params: { issue_type: 'issue' },
                widget_params: widget_params
              ).execute(work_item)

              expect(work_item.reload.status_with_fallback).to eq(lifecycle.default_open_status)

              described_class.new(
                container: project,
                current_user: current_user,
                params: { issue_type: 'task' },
                widget_params: widget_params
              ).execute(work_item)

              expect(work_item.reload.status_with_fallback).to eq(lifecycle_2.default_open_status)
            end
          end
        end

        context 'when work item type does not support configurable statuses' do
          let!(:issue_type_custom_lifecycle) do
            create(:work_item_type_custom_lifecycle,
              work_item_type: issue_work_item_type, lifecycle: lifecycle, namespace: group
            )
          end

          let(:params) { { issue_type: 'incident' } }

          it 'updates the work item type but without any status' do
            expect { update_work_item }
              .to change { work_item.reload.work_item_type }
              .from(issue_work_item_type).to(incident_work_item_type)
              .and change { work_item.status_with_fallback }
              .from(lifecycle.default_open_status).to(nil)
          end

          it_behaves_like 'update service that triggers GraphQL work_item_updated subscription' do
            subject(:execute_service) { update_work_item }
          end
        end
      end
    end
  end
end
