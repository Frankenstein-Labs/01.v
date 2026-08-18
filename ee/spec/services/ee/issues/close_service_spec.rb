# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issues::CloseService, feature_category: :team_planning do
  describe '#execute' do
    before do
      stub_licensed_features(epics: true)
    end

    context 'when project bot it logs audit events' do
      let(:service) { described_class.new(container: project, current_user: project_bot) }
      let_it_be(:project_bot) { create(:user, :project_bot, email: "bot@example.com") }
      let_it_be(:project) { create(:project, maintainers: project_bot) }

      include_examples 'audit event logging' do
        let(:issue) { create(:issue, title: "My issue", project: project, author: project_bot) }
        let(:operation) { service.execute(issue) }
        let(:event_type) { 'issue_closed_by_project_bot' }
        let(:fail_condition!) { expect(project_bot).to receive(:project_bot?).and_return(false) }
        let(:attributes) do
          {
            author_id: project_bot.id,
            entity_id: issue.project.id,
            entity_type: 'Project',
            details: {
              author_name: project_bot.name,
              event_name: "issue_closed_by_project_bot",
              target_id: issue.id,
              target_type: 'Issue',
              target_details: {
                iid: issue.iid,
                id: issue.id
              }.to_s,
              author_class: project_bot.class.name,
              custom_message: "Closed issue #{issue.title}"
            }
          }
        end
      end
    end

    context 'when project bot closes a ticket it logs audit events' do
      let(:service) { described_class.new(container: project, current_user: project_bot) }
      let_it_be(:project_bot) { create(:user, :project_bot, email: "bot@example.com") }
      let_it_be(:project) { create(:project, maintainers: project_bot) }

      include_examples 'audit event logging' do
        let(:ticket) { create(:issue, :ticket, title: "My ticket", project: project, author: project_bot) }
        let(:operation) { service.execute(ticket) }
        let(:event_type) { 'ticket_closed_by_project_bot' }
        let(:fail_condition!) { expect(project_bot).to receive(:project_bot?).and_return(false) }
        let(:attributes) do
          {
            author_id: project_bot.id,
            entity_id: ticket.project.id,
            entity_type: 'Project',
            details: {
              author_name: project_bot.name,
              event_name: "ticket_closed_by_project_bot",
              target_id: ticket.id,
              target_type: 'Issue',
              target_details: {
                iid: ticket.iid,
                id: ticket.id
              }.to_s,
              author_class: project_bot.class.name,
              custom_message: "Closed ticket #{ticket.title}"
            }
          }
        end
      end
    end

    context 'when is epic work item' do
      let_it_be_with_reload(:current_user) { create(:user) }
      let(:service) { described_class.new(container: group, current_user: current_user) }
      let_it_be_with_reload(:group) { create(:group) }

      let_it_be_with_reload(:work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
      let_it_be_with_reload(:epic) { work_item.synced_epic }

      subject(:execute) { service.execute(work_item) }

      before_all do
        group.add_developer(current_user)
      end

      it_behaves_like 'syncs all data from an epic to a work item'

      it 'syncs the state to the epic' do
        expect { execute }.to change { epic.reload.state }.from('opened').to('closed')
          .and change { work_item.reload.state }.from('opened').to('closed')

        expect(work_item.closed_by).to eq(epic.closed_by)
        expect(work_item.closed_at).to eq(epic.closed_at)
      end

      it 'publishes a work item closed event' do
        expect { execute }
          .to publish_event(::WorkItems::WorkItemClosedEvent)
          .with({
            id: work_item.id,
            namespace_id: work_item.namespace.id
          })
      end

      context 'when epic and work item was already closed' do
        before do
          epic.close!
          work_item.close!
        end

        it 'does not change the state' do
          expect { execute }.to not_change { epic.reload.state }
            .and not_change { work_item.reload.state }
        end
      end

      context 'when the epic is already closed' do
        before do
          epic.close!
          epic.update!(closed_by: create(:user), closed_at: Time.current - 1.day)
        end

        it 'does not error and syncs closed_at and closed_by' do
          expect { execute }.not_to raise_error

          expect(work_item.reload.state).to eq('closed')
          expect(epic.reload.state).to eq('closed')
          expect(work_item.closed_at).to eq(epic.closed_at)
          expect(work_item.closed_by).to eq(epic.closed_by)
        end
      end

      context 'when closing the epic fails due an other error' do
        before do
          allow_next_found_instance_of(Epic) do |epic|
            allow(epic).to receive(:close!).and_raise(ActiveRecord::RecordInvalid.new)
          end
        end

        it 'rolls back updating the work_item, logs error and raises it' do
          expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
            .with({
              message: "Not able to sync closing epic work item",
              error_message: 'Record invalid',
              work_item_id: work_item.id
            })

          expect(Gitlab::ErrorTracking)
            .to receive(:track_and_raise_exception)
                  .with(an_instance_of(ActiveRecord::RecordInvalid), { work_item_id: work_item.id })
                  .and_call_original

          expect { execute }.to raise_error(ActiveRecord::RecordInvalid)

          expect(work_item.reload.state).to eq('opened')
          expect(epic.reload.state).to eq('opened')
        end
      end

      context 'when it has no legacy epic' do
        let_it_be_with_reload(:work_item) { create(:work_item, :epic, namespace: group) }

        it 'closes the work item' do
          execute

          expect(work_item.reload.state).to eq('closed')
        end
      end
    end

    context 'when closing regular work items' do
      let_it_be_with_reload(:current_user) { create(:user) }
      let_it_be_with_reload(:group) { create(:group) }
      let_it_be_with_reload(:task_work_item) { create(:work_item, :task, namespace: group) }

      let(:service) { described_class.new(container: group, current_user: current_user) }

      subject(:execute) { service.execute(task_work_item) }

      before_all do
        group.add_developer(current_user)
      end

      it 'publishes a work item closed event for tasks' do
        expect { execute }
          .to publish_event(::WorkItems::WorkItemClosedEvent)
          .with({
            id: task_work_item.id,
            namespace_id: task_work_item.namespace.id
          })
      end

      it 'closes the task work item' do
        expect { execute }.to change { task_work_item.reload.state }.from('opened').to('closed')
      end

      context 'with weight rollup scenarios' do
        let_it_be(:project) { create(:project, developers: current_user) }
        let_it_be_with_reload(:parent_issue) { create(:work_item, :issue, project: project) }
        let_it_be_with_reload(:child_task_1) { create(:work_item, :task, project: project, weight: 3) }
        let_it_be_with_reload(:child_task_2) { create(:work_item, :task, project: project, weight: 2) }

        let_it_be(:parent_link_1, freeze: false) do
          create(:parent_link, work_item: child_task_1, work_item_parent: parent_issue)
        end

        let_it_be(:parent_link_2, freeze: false) do
          create(:parent_link, work_item: child_task_2, work_item_parent: parent_issue)
        end

        it 'triggers weight update when child is closed', :sidekiq_inline do
          expect(WorkItems::Weights::UpdateWeightsWorker)
            .to receive(:perform_async)
            .with(array_including(child_task_1.id))

          described_class.new(container: project, current_user: current_user).execute(child_task_1)
        end
      end
    end

    context "for current_status" do
      let_it_be_with_reload(:current_user) { create(:user) }
      let_it_be_with_reload(:group) { create(:group) }
      let_it_be_with_reload(:project) { create(:project, group: group) }
      let_it_be_with_reload(:work_item) { create(:work_item, :task, project: project) }

      let(:closed_status) { build(:work_item_system_defined_status, :done) }
      let(:duplicated_status) { build(:work_item_system_defined_status, :duplicate) }
      let(:status_update_service) { instance_double(::WorkItems::Widgets::Statuses::UpdateService) }

      subject(:execute) do
        described_class.new(container: group, current_user: current_user).execute(work_item, status: status)
      end

      before_all do
        group.add_developer(current_user)
      end

      before do
        stub_licensed_features(work_item_status: true)
      end

      context "when status is present" do
        let(:status) { closed_status }

        it "calls the status update service" do
          expect(::WorkItems::Widgets::Statuses::UpdateService).to receive(:new)
            .with(work_item, current_user, closed_status)
            .and_return(status_update_service)
          expect(status_update_service).to receive(:execute)

          execute
        end
      end

      context "when the status is nil" do
        let(:status) { nil }

        it 'does not call the status update service' do
          expect(::WorkItems::Widgets::Statuses::UpdateService).not_to receive(:new)

          execute
        end

        context 'when issue has an existing current status record' do
          before do
            create(
              :work_item_current_status,
              work_item_id: work_item.id,
              system_defined_status_id: build(:work_item_system_defined_status, :to_do).id
            )
          end

          it "calls the status update service" do
            expect(::WorkItems::Widgets::Statuses::UpdateService).to receive(:new)
              .with(work_item, current_user, :default)
              .and_return(status_update_service)
            expect(status_update_service).to receive(:execute)

            execute
          end
        end

        context 'when namespace has a custom lifecycle' do
          let!(:custom_lifecycle) do
            create(:work_item_custom_lifecycle, namespace: group).tap do |lifecycle|
              create(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: work_item.work_item_type)
            end
          end

          it "calls the status update service" do
            expect(::WorkItems::Widgets::Statuses::UpdateService).to receive(:new)
              .with(work_item, current_user, :default)
              .and_return(status_update_service)
            expect(status_update_service).to receive(:execute)

            execute
          end

          context 'when feature becomes unlicensed' do
            before do
              custom_lifecycle

              stub_licensed_features(work_item_status: false)
            end

            it "calls the status update service with the default open status" do
              expect(::WorkItems::Widgets::Statuses::UpdateService).to receive(:new)
                .with(work_item, current_user, :default)
                .and_return(status_update_service)
              expect(status_update_service).to receive(:execute)

              execute
            end
          end
        end
      end

      context 'when an issue is closed' do
        let_it_be_with_reload(:issue) { create(:issue, project: project) }

        subject(:execute) do
          described_class.new(container: project, current_user: current_user).execute(issue)
        end

        before do
          create(
            :work_item_current_status,
            work_item_id: issue.id,
            system_defined_status_id: build(:work_item_system_defined_status, :in_progress).id
          )
          issue.association(:current_status).reset
        end

        it 'includes the status transition in the webhook changes payload' do
          old_status = issue.status_with_fallback

          execute

          hook_data = issue.to_hook_data(current_user,
            old_associations: { status: old_status },
            action: 'update')

          status_change = hook_data[:changes][:status]
          expect(status_change[:previous]).to include('name' => 'In progress', 'category' => :in_progress)
          expect(status_change[:current]).to include('name' => 'Done', 'category' => :done)
        end
      end
    end
  end
end
