# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issues::ReopenService, feature_category: :team_planning do
  describe '#execute' do
    before do
      stub_licensed_features(epics: true)
    end

    context 'when project bot it logs audit events' do
      let(:service) { described_class.new(container: project, current_user: project_bot) }
      let_it_be(:project_bot) { create(:user, :project_bot, email: "bot@example.com") }
      let_it_be(:project) { create(:project, :small_repo, maintainers: project_bot) }

      include_examples 'audit event logging' do
        let(:issue) { create(:issue, :closed, title: "My issue", project: project, author: project_bot) }
        let(:operation) { service.execute(issue) }
        let(:event_type) { 'issue_reopened_by_project_bot' }
        let(:fail_condition!) { expect(project_bot).to receive(:project_bot?).and_return(false) }
        let(:attributes) do
          {
            author_id: project_bot.id,
            entity_id: issue.project.id,
            entity_type: 'Project',
            details: {
              author_name: project_bot.name,
              event_name: 'issue_reopened_by_project_bot',
              target_id: issue.id,
              target_type: 'Issue',
              target_details: {
                iid: issue.iid,
                id: issue.id
              }.to_s,
              author_class: project_bot.class.name,
              custom_message: "Reopened issue #{issue.title}"
            }
          }
        end
      end
    end

    context 'when project bot reopens a ticket it logs audit events' do
      let(:service) { described_class.new(container: project, current_user: project_bot) }
      let_it_be(:project_bot) { create(:user, :project_bot, email: "bot@example.com") }
      let_it_be(:project) { create(:project, :small_repo, maintainers: project_bot) }

      include_examples 'audit event logging' do
        let(:ticket) { create(:issue, :ticket, :closed, title: "My ticket", project: project, author: project_bot) }
        let(:operation) { service.execute(ticket) }
        let(:event_type) { 'ticket_reopened_by_project_bot' }
        let(:fail_condition!) { expect(project_bot).to receive(:project_bot?).and_return(false) }
        let(:attributes) do
          {
            author_id: project_bot.id,
            entity_id: ticket.project.id,
            entity_type: 'Project',
            details: {
              author_name: project_bot.name,
              event_name: 'ticket_reopened_by_project_bot',
              target_id: ticket.id,
              target_type: 'Issue',
              target_details: {
                iid: ticket.iid,
                id: ticket.id
              }.to_s,
              author_class: project_bot.class.name,
              custom_message: "Reopened ticket #{ticket.title}"
            }
          }
        end
      end
    end

    context 'when is epic work item' do
      let_it_be(:current_user) { create(:user) }
      let_it_be(:group) { create(:group) }

      let_it_be_with_reload(:work_item) { create(:work_item, :closed, :epic_with_legacy_epic, namespace: group) }
      let_it_be_with_reload(:epic) { work_item.synced_epic }
      let(:service) { described_class.new(container: group, current_user: current_user) }

      subject(:execute) { service.execute(work_item) }

      before_all do
        group.add_maintainer(current_user)
      end

      it_behaves_like 'syncs all data from an epic to a work item'

      it 'syncs the state to the epic' do
        expect { execute }.to change { epic.reload.state }.from('closed').to('opened')
          .and change { work_item.reload.state }.from('closed').to('opened')

        expect(work_item.closed_by).to be_nil
        expect(work_item.closed_at).to be_nil
      end

      it 'publishes a work item reopened event' do
        expect { execute }
          .to publish_event(::WorkItems::WorkItemReopenedEvent)
          .with({
            id: work_item.id,
            namespace_id: work_item.namespace.id
          })
      end

      context 'when epic and work item was already opened' do
        before do
          epic.reopen!
          work_item.reopen!
        end

        it 'does not change the state' do
          expect { execute }.to not_change { epic.reload.state }
            .and not_change { work_item.reload.state }
        end
      end

      context 'when the epic is already open' do
        before do
          epic.reopen!
        end

        it 'does not error and changes both to open' do
          expect { execute }.not_to raise_error

          expect(work_item.reload.state).to eq('opened')
          expect(epic.reload.state).to eq('opened')
        end
      end

      context 'when reopening the epic fails due to an error' do
        before do
          allow_next_found_instance_of(Epic) do |epic|
            allow(epic).to receive(:reopen!).and_raise(ActiveRecord::RecordInvalid.new)
          end
        end

        it 'rolls back updating the work_item, logs error and raises it' do
          expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
            .with({
              message: "Not able to sync reopening epic work item",
              error_message: 'Record invalid',
              work_item_id: work_item.id
            })

          expect(Gitlab::ErrorTracking)
            .to receive(:track_and_raise_exception)
                  .with(an_instance_of(ActiveRecord::RecordInvalid), { work_item_id: work_item.id })
                  .and_call_original

          expect { execute }.to raise_error(ActiveRecord::RecordInvalid)

          expect(work_item.reload.state).to eq('closed')
          expect(epic.reload.state).to eq('closed')
        end
      end

      context 'when it has no legacy epic' do
        let_it_be_with_reload(:work_item) { create(:work_item, :closed, :epic, namespace: group) }

        it 'reopens the work item' do
          execute

          expect(work_item.reload.state).to eq('opened')
        end
      end
    end

    context 'when reopening regular work items' do
      let_it_be(:current_user) { create(:user) }
      let_it_be(:group) { create(:group) }
      let_it_be_with_reload(:task_work_item) { create(:work_item, :task, :closed, namespace: group) }

      let(:service) { described_class.new(container: group, current_user: current_user) }

      subject(:execute) { service.execute(task_work_item) }

      before_all do
        group.add_developer(current_user)
      end

      it 'publishes a work item reopened event for tasks' do
        expect { execute }
          .to publish_event(::WorkItems::WorkItemReopenedEvent)
          .with({
            id: task_work_item.id,
            namespace_id: task_work_item.namespace.id
          })
      end

      it 'reopens the task work item' do
        expect { execute }.to change { task_work_item.reload.state }.from('closed').to('opened')
      end

      context 'with weight rollup scenarios' do
        let_it_be(:project) { create(:project, developers: current_user) }
        let_it_be(:parent_issue) { create(:work_item, :issue, project: project) }
        let_it_be_with_reload(:child_task_1) { create(:work_item, :task, project: project, weight: 3) }
        let_it_be(:child_task_2) { create(:work_item, :task, project: project, weight: 2) }

        let_it_be(:parent_link_1) { create(:parent_link, work_item: child_task_1, work_item_parent: parent_issue) }
        let_it_be(:parent_link_2) { create(:parent_link, work_item: child_task_2, work_item_parent: parent_issue) }

        before do
          # Close the child task so it can be reopened in the test
          child_task_1.close!
          # Initialize parent weights with all children closed
          WorkItems::Weights::UpdateWeightsService.new([parent_issue]).execute
        end

        it 'triggers weight update when child is reopened', :sidekiq_inline do
          expect(WorkItems::Weights::UpdateWeightsWorker)
            .to receive(:perform_async)
            .with(array_including(child_task_1.id))

          described_class.new(container: project, current_user: current_user).execute(child_task_1)
        end
      end
    end

    context "when current_status" do
      let_it_be(:current_user) { create(:user) }
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be_with_reload(:work_item) { create(:work_item, :task, :closed, project: project) }

      let(:status_update_service) { instance_double(::WorkItems::Widgets::Statuses::UpdateService) }
      let(:opened_status) { build(:work_item_system_defined_status, :to_do) }
      let(:in_progress_status) { build(:work_item_system_defined_status, :in_progress) }

      subject(:execute) do
        described_class.new(container: group, current_user: current_user).execute(work_item, status: status)
      end

      before_all do
        group.add_maintainer(current_user)
      end

      before do
        stub_licensed_features(work_item_status: true)
      end

      context "when argument status is nil" do
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
              system_defined_status_id: build(:work_item_system_defined_status, :done).id
            )
          end

          it "calls the status update service with the default status" do
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

          it "calls the status update service with the default status" do
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

            it "calls the status update service with the default status" do
              expect(::WorkItems::Widgets::Statuses::UpdateService).to receive(:new)
                .with(work_item, current_user, :default)
                .and_return(status_update_service)
              expect(status_update_service).to receive(:execute)

              execute
            end
          end
        end
      end

      context "when argument status is not nil" do
        let(:status) { in_progress_status }

        it "calls the status update service with the given status" do
          expect(::WorkItems::Widgets::Statuses::UpdateService).to receive(:new)
            .with(work_item, current_user, in_progress_status)
            .and_return(status_update_service)
          expect(status_update_service).to receive(:execute)

          execute
        end
      end

      context 'when an issue is reopened' do
        let_it_be_with_reload(:issue) { create(:issue, :closed, project: project) }

        subject(:execute) do
          described_class.new(container: project, current_user: current_user).execute(issue)
        end

        before do
          create(
            :work_item_current_status,
            work_item_id: issue.id,
            system_defined_status_id: build(:work_item_system_defined_status, :done).id
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
          expect(status_change[:previous]).to include('name' => 'Done', 'category' => :done)
          expect(status_change[:current]).to include('name' => 'To do', 'category' => :to_do)
        end
      end
    end
  end
end
