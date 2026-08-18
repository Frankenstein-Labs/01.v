# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issues::CreateService, feature_category: :team_planning do
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, group: group) }

  let(:base_params) { { title: 'Awesome issue', description: 'please fix', weight: 9 } }
  let(:additional_params) { {} }
  let(:params) { base_params.merge(additional_params) }
  let(:service) { described_class.new(container: project, current_user: user, params: params) }
  let(:created_issue) { service.execute[:issue] }

  describe '#execute' do
    context 'when current user cannot admin issues in the project' do
      let_it_be(:iteration, freeze: false) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: group), start_date: 14.days.ago, due_date: 5.days.ago) }

      let(:additional_params) { { iteration: iteration, sprint_id: iteration.id } }

      before do
        project.add_guest(user)
        stub_licensed_features(iterations: true)
      end

      it 'filters out params that cannot be set without the :admin_issue permission' do
        expect(created_issue).to be_persisted
        expect(created_issue.weight).to be_nil
        expect(created_issue.iteration).to be_nil
      end
    end

    context 'with onboarding progress' do
      before_all do
        project.add_guest(user)
      end

      context 'when issue creation is successful' do
        it 'invokes an async onboarding progress update' do
          expect(Onboarding::ProgressService).to receive(:async).with(project.project_namespace_id, 'issue_created')

          created_issue
        end
      end

      context 'when issue creation fails' do
        let(:additional_params) { { title: '' } }

        it 'does not invoke an async onboarding progress update' do
          expect(Onboarding::ProgressService).not_to receive(:async)

          created_issue
        end
      end
    end

    context 'when current user can admin issues in the project' do
      before do
        stub_licensed_features(epics: true)
        project.add_reporter(user)
      end

      it 'sets permitted params correctly' do
        expect(created_issue).to be_persisted
        expect(created_issue.weight).to eq(9)
      end

      context 'when epics are enabled' do
        let_it_be(:epic, freeze: false) { create(:epic, group: group, start_date_is_fixed: false, due_date_is_fixed: false) }

        before do
          stub_licensed_features(epics: true)
          project.add_reporter(user)
        end

        it_behaves_like 'issue with epic_id parameter' do
          let(:execute) { service.execute }
          let(:returned_issue) { execute[:issue] }
        end

        context 'when using quick actions' do
          before do
            group.add_reporter(user)
          end

          context '/epic action' do
            let(:params) { { title: 'New issue', description: "/epic #{epic.to_reference(project)}" } }

            it 'adds an issue to the passed epic' do
              expect(created_issue).to be_persisted
              expect(created_issue.reload.epic).to eq(epic)
              expect(created_issue.confidential).to eq(false)
            end
          end

          context 'with epic and milestone in commands only' do
            let_it_be(:milestone, freeze: false) { create(:milestone, group: group, start_date: Date.today, due_date: 7.days.from_now) }
            let_it_be(:assignee_user1, freeze: false) { create(:user) }
            let(:params) do
              {
                title: 'Awesome issue',
                description: %(/epic #{epic.to_reference}\n/milestone #{milestone.to_reference}\n/assign #{assignee_user1.to_reference})
              }
            end

            before do
              project.add_guest(assignee_user1)
            end

            it 'sets epic and milestone to issuable and update epic start and due date' do
              expect(created_issue.milestone).to eq(milestone)
              expect(created_issue.reload.epic).to eq(epic)
              expect(epic.reload.start_date).to eq(milestone.start_date)
              expect(epic.due_date).to eq(milestone.due_date)
            end

            it 'generates system notes for adding an epic and milestone', :sidekiq_inline do
              expect { service.execute }.to change { Note.count }.by(3).and(change { ResourceMilestoneEvent.count }.by(1))
            end

            context 'when assigning epic raises an exception' do
              let(:mock_service) { double('service', execute: { status: :error, message: 'failed to assign epic' }) }

              it 'assigns the issue passed to the provided epic' do
                expect(::WorkItems::LegacyEpics::EpicIssues::CreateService).to receive(:new).and_return(mock_service)

                expect { service.execute }.to raise_error(EE::Issues::BaseService::EpicAssignmentError, 'failed to assign epic')
              end
            end
          end

          context 'when adding a public issue to confidential epic' do
            let(:confidential_epic) { create(:epic, group: group, confidential: true) }
            let(:params) { { title: 'confidential issue', epic_id: confidential_epic.id } }

            it 'creates confidential child issue' do
              expect(created_issue).to be_confidential
            end
          end

          context 'when adding a confidential issue to public epic' do
            let(:params) { { title: 'confidential issue', epic_id: epic.id, confidential: true } }

            it 'creates a confidential child issue' do
              expect(created_issue).to be_confidential
            end
          end
        end
      end

      context 'when iterations are available' do
        let_it_be(:iteration_cadence1, freeze: false) { create(:iterations_cadence, group: group) }
        let_it_be(:iteration_cadence2, freeze: false) { create(:iterations_cadence, group: group) }
        let_it_be(:current_iteration1, freeze: false) { create(:iteration, iterations_cadence: iteration_cadence1, start_date: 4.days.ago, due_date: 3.days.from_now) }
        let_it_be(:current_iteration2, freeze: false) { create(:iteration, iterations_cadence: iteration_cadence2, start_date: 4.days.ago, due_date: 3.days.from_now) }
        let_it_be(:future_iteration, freeze: false) { create(:iteration, iterations_cadence: iteration_cadence1, start_date: 6.days.from_now, due_date: 13.days.from_now) }

        before do
          stub_licensed_features(iterations: true)
        end

        RSpec.shared_examples 'create with specify column' do |column|
          context 'when user can read the given iteration' do
            let(:additional_params) { { column => future_iteration.id } }

            it 'is successful, and assigns the specified iteration to the issue' do
              expect(created_issue).to be_persisted
              expect(created_issue).to have_attributes(iteration: future_iteration)
            end
          end

          context "when user can't read the given iteration" do
            let(:private_group) { create(:group, :private) }
            let(:additional_params) { { column => create(:iteration, iterations_cadence: create(:iterations_cadence, group: private_group)).id } }

            it 'is successful but does not assign the iteration' do
              expect(created_issue).to be_persisted
              expect(created_issue).to have_attributes(iteration: nil)
            end
          end

          context 'when iteration_wildcard_id is provided' do
            let(:additional_params) { { column => future_iteration.id, iteration_wildcard_id: 'CURRENT', iteration_cadence_id: iteration_cadence2.id } }

            it 'raises a mutually exclusive argument error' do
              expect { service.execute }.to raise_error(
                ::Issues::BaseService::IterationAssignmentError,
                "Incompatible arguments: #{column}, iteration_wildcard_id."
              )
            end
          end
        end

        context 'when sprint_id is provided' do
          it_behaves_like 'create with specify column', :sprint_id
        end

        context 'when iteration_id is provided' do
          it_behaves_like 'create with specify column', :iteration_id
        end

        context 'when both sprint_id and iteration_id is provided' do
          let(:additional_params) { { sprint_id: future_iteration.id, iteration_id: future_iteration.id } }

          it 'raises a mutually exclusive argument error' do
            expect { service.execute }.to raise_error(
              ::Issues::BaseService::IterationAssignmentError,
              'Incompatible arguments: iteration_id, sprint_id.'
            )
          end
        end

        context 'when iteration_wildcard_id is provided' do
          context 'when iteration_wildcard_id is CURRENT' do
            let(:additional_params) { { iteration_wildcard_id: 'CURRENT' } }

            context 'when iteration_cadence_id is provided' do
              let(:additional_params) { { iteration_wildcard_id: 'CURRENT', iteration_cadence_id: iteration_cadence2.id } }

              it 'is successful, and assigns the current iteration to the issue' do
                expect(created_issue).to be_persisted
                expect(created_issue).to have_attributes(iteration: current_iteration2)
              end
            end

            context 'when iteration_cadence_id is not provided' do
              it 'always requires iteration cadence id when wildcard is provided' do
                expect { service.execute }.to raise_error(
                  ::Issues::BaseService::IterationAssignmentError,
                  'iteration_cadence_id is required when iteration_wildcard_id is provided.'
                )
              end
            end
          end

          context 'when iteration_wildcard_id is invalid' do
            let(:additional_params) { { iteration_wildcard_id: 'INVALID', iteration_cadence_id: iteration_cadence2.id } }

            it 'is successful, and does not assign an iteration to the issue' do
              expect(created_issue).to be_persisted
              expect(created_issue).to have_attributes(iteration: nil)
            end
          end
        end

        context 'when no iteration params are provided' do
          it 'is successful, and does not assign an iteration to the issue' do
            expect(created_issue).to be_persisted
            expect(created_issue).to have_attributes(iteration: nil)
          end
        end
      end

      context 'when issue is of requirement_type' do
        let(:params) { { title: 'Requirement Issue', description: 'Should sync', issue_type: 'requirement' } }

        before_all do
          project.add_reporter(user)
        end

        before do
          stub_licensed_features(requirements: true)
        end

        it 'creates one requirement and one requirement issue' do
          expect { service.execute }.to change { Issue.count }.by(1)
            .and change { RequirementsManagement::Requirement.count }.by(1)
        end

        it 'creates a requirement object with same parameters' do
          result = service.execute
          issue = result[:issue]
          requirement = issue.reload.requirement

          expect(result).to be_success
          expect(requirement.title).to eq(issue.title)
          expect(requirement.description).to eq(issue.description)
          expect(requirement.state).to eq(issue.state)
          expect(requirement.project).to eq(issue.project)
          expect(requirement.author).to eq(issue.author)
          expect(issue.work_item_type.requirement?).to eq(true)
        end

        context 'when creation of requirement fails' do
          it 'does not create issue' do
            allow_next_instance_of(RequirementsManagement::Requirement) do |instance|
              allow(instance).to receive(:valid?).and_return(false)
            end

            expect { service.execute }
              .to not_change { Issue.count }
              .and not_change { RequirementsManagement::Requirement.count }
          end
        end

        context 'when creation of issue fails' do
          it 'does not create requirement' do
            allow_next_instance_of(Issue) do |instance|
              allow(instance).to receive(:valid?).and_return(false)
            end

            expect { service.execute }
              .to not_change { Issue.count }
              .and not_change { RequirementsManagement::Requirement.count }
          end
        end

        context 'when requirements feature is not available' do
          before do
            stub_licensed_features(requirements: false)
          end

          it 'creates a issue work item' do
            expect { service.execute }
              .to change { Issue.with_issue_type(:issue).count }.by(1)
              .and not_change { RequirementsManagement::Requirement.count }
          end
        end
      end

      context 'with multiple assignees', :sidekiq_inline do
        let_it_be(:project, freeze: false) { create(:project, :public, group: group) }

        let_it_be(:users, freeze: false) do
          users = build_list(:user, 15)
          user_attributes = users.map { |user| user.attributes.except('id', 'otp_secret') }
          user_ids = User.insert_all(user_attributes, returning: :id).rows.flatten

          level = NotificationSetting.levels[::User::DEFAULT_NOTIFICATION_LEVEL]
          users_global_notifications = user_ids.map do |user_id|
            { user_id: user_id, source_id: nil, source_type: nil, level: level, created_at: Time.current }
          end
          NotificationSetting.insert_all(users_global_notifications)

          User.id_in(user_ids)
        end

        let(:params) { { title: 'Title', description: 'Description', assignee_ids: users.map(&:id) } }

        it 'does not raise `ThresholdExceededError` error' do
          expect { service.execute }.not_to raise_error
        end

        it 'keeps queries count under threshold' do
          new_users = create_list(:user, 2)
          params = { title: 'Title', description: 'Description', assignee_ids: new_users.map(&:id) }

          control = ActiveRecord::QueryRecorder.new do
            described_class.new(container: project, current_user: user, params: params).execute
          end

          # Currently, when creating an issue we create each issue_assignee record separately, so we fire 6 queries for
          # each one of those:
          # - load the user
          # - validates that username is unique, see User model
          # - validates `ensure_namespace_correct`, see User model
          # - check user within namespace_bans within EE
          # - validates user is the unique assignee in scope of the issue, see IssueAssignee model
          # - inserts the issue assignee record
          #
          # So we add these as a threshold to the control query: 33*5
          expect { service.execute }.not_to exceed_query_limit(control).with_threshold(15 * 6)
        end
      end
    end

    context 'when zoom and severity quick action is used together' do
      let(:params) do
        { title: 'New incident',
          description: "/zoom https://gitlab.zoom.us/j/1234\n/severity 1",
          issue_type: :incident }
      end

      before do
        stub_licensed_features(issuable_resource_links: true)
        project.add_reporter(user)
      end

      it 'adds the link and assigns the severity without any regression' do
        expect(created_issue).to be_persisted
        expect(created_issue.issuable_resource_links.last.link).to eq('https://gitlab.zoom.us/j/1234')
        expect(created_issue.severity).to eq('critical')
      end
    end

    context 'when handling linked observability metrics' do
      before_all do
        project.add_developer(user)
      end

      let(:additional_params) do
        { observability_links: { metric_details_name: "test name", metric_details_type: "sum_type" } }
      end

      let(:execute) { service.execute }
      let(:returned_issue) { execute[:issue] }

      context 'when observability is enabled and licensed' do
        before do
          stub_licensed_features(observability: true)
        end

        it "creates a linked metric" do
          expect { execute }.to change { ::Observability::MetricsIssuesConnection.count }.by(1)
        end

        context 'when no o11y params exist' do
          let(:additional_params) { {} }

          it "creates no linked metrics" do
            expect { execute }.not_to change { ::Observability::MetricsIssuesConnection.count }
          end

          it "creates an issue" do
            expect { execute }.to change { ::Issue.count }.by(1)
          end
        end
      end

      context 'when observability is not enabled and licensed' do
        before do
          stub_feature_flags(observability_features: false)
          stub_licensed_features(observability: false)
        end

        it "creates a linked metric" do
          expect { execute }.not_to change { ::Observability::MetricsIssuesConnection.count }
        end
      end
    end

    context 'when handling issues linked to observability logs' do
      before_all do
        project.add_developer(user)
      end

      let(:additional_params) do
        {
          observability_links: {
            log_service_name: "test service name",
            log_severity_number: 9,
            log_timestamp: 1.day.ago.to_date,
            log_trace_id: "fa12d360-54cd-c4db-5241-ccf7841d3e72",
            log_fingerprint: "03fe551c28e5c64b"
          }
        }
      end

      let(:execute) { service.execute }
      let(:returned_issue) { execute[:issue] }

      context 'when observability is enabled and licensed' do
        before do
          stub_licensed_features(observability: true)
        end

        it "creates a logs connection" do
          expect { execute }.to change { ::Observability::LogsIssuesConnection.count }.by(1)
        end

        context 'when no o11y params exist' do
          let(:additional_params) { {} }

          it "creates no logs connection" do
            expect { execute }.not_to change { ::Observability::LogsIssuesConnection.count }
          end

          it "creates an issue" do
            expect { execute }.to change { ::Issue.count }.by(1)
          end
        end
      end

      context 'when observability is not enabled and licensed' do
        before do
          stub_feature_flags(observability_features: false)
          stub_licensed_features(observability: false)
        end

        it "creates no logs connection" do
          expect { execute }.not_to change { ::Observability::LogsIssuesConnection.count }
        end
      end
    end

    context 'when handling issues linked to observability traces' do
      before_all do
        project.add_developer(user)
      end

      let(:additional_params) do
        {
          observability_links: {
            trace_id: "fa12d360-54cd-c4db-5241-ccf7841d3e72"
          }
        }
      end

      let(:execute) { service.execute }
      let(:returned_issue) { execute[:issue] }

      context 'when observability is enabled and licensed' do
        before do
          stub_licensed_features(observability: true)
        end

        it "creates a traces connection" do
          expect { execute }.to change { ::Observability::TracesIssuesConnection.count }.by(1)
        end

        context 'when no o11y params exist' do
          let(:additional_params) { {} }

          it "creates no traces connection" do
            expect { execute }.not_to change { ::Observability::TracesIssuesConnection.count }
          end

          it "creates an issue" do
            expect { execute }.to change { ::Issue.count }.by(1)
          end
        end
      end

      context 'when observability is not enabled and licensed' do
        before do
          stub_feature_flags(observability_features: false)
          stub_licensed_features(observability: false)
        end

        it "creates no traces connection" do
          expect { execute }.not_to change { ::Observability::TracesIssuesConnection.count }
        end
      end
    end

    context "when handling status" do
      let(:other_status) { build(:work_item_system_defined_status, :wont_do) }

      before_all do
        project.add_developer(user)
      end

      before do
        stub_licensed_features(work_item_status: true)
      end

      context "without status params" do
        let(:additional_params) { {} }

        it 'creates new issue and creates a current status record' do
          expect { created_issue }.to change { Issue.count }.by(1).and(
            change { WorkItems::Statuses::CurrentStatus.count }.by(1)
          )
        end
      end

      context "with status params" do
        let(:additional_params) { { status: other_status } }

        it 'creates new issue and creates a current status recor' do
          expect { created_issue }.to change { Issue.count }.by(1).and(
            change { WorkItems::Statuses::CurrentStatus.count }.by(1)
          )
        end
      end
    end

    it_behaves_like 'new issuable with scoped labels' do
      let(:parent) { project }
      let(:service_result) { described_class.new(**args).execute }
      let(:issuable) { service_result[:issue] }
    end
  end

  context 'with Amazon Q disabled' do
    let(:params) { { title: 'Write hello world', description: '/q dev' } }

    before do
      project.add_developer(user)
    end

    context '/q dev' do
      it 'does not trigger the Amazon Q service' do
        expect(::Ai::AmazonQ::AmazonQTriggerService).not_to receive(:new)
        expect(created_issue).to be_persisted
      end
    end
  end

  context 'with Amazon Q enabled' do
    let(:params) { ActionController::Parameters.new(title: 'Write hello world', description: '/q dev').permit(:title, :description) }

    before do
      allow(::Ai::AmazonQ).to receive(:enabled?).and_return(true)
      project.add_developer(user)
    end

    context '/q dev' do
      let(:trigger_service) { instance_double(::Ai::AmazonQ::AmazonQTriggerService) }

      it 'triggers the Amazon Q service' do
        expect(trigger_service).to receive(:execute)
        expect(::Ai::AmazonQ::AmazonQTriggerService).to receive(:new).with(
          user: user,
          command: 'dev',
          source: an_instance_of(Issue)
        ).and_return(trigger_service)

        expect(created_issue).to be_persisted
      end
    end
  end

  describe 'AI flow triggers on assignment' do
    let_it_be(:service_account_1, freeze: false) { create(:service_account, username: 'flow-trigger-1') }
    let_it_be(:service_account_2, freeze: false) { create(:service_account, username: 'flow-trigger-2') }
    let_it_be(:service_account_3, freeze: false) { create(:service_account, username: 'flow-trigger-3') }
    let_it_be(:regular_user, freeze: false) { create(:user) }
    let_it_be(:flow_trigger_1, freeze: false) { create(:ai_flow_trigger, project: project, event_types: [1], user: service_account_1) }
    let_it_be(:flow_trigger_2, freeze: false) { create(:ai_flow_trigger, project: project, event_types: [1], user: service_account_2) }
    let_it_be(:flow_trigger_3, freeze: false) { create(:ai_flow_trigger, project: project, event_types: [0], user: service_account_3) }

    let(:run_service_1) { instance_double(::Ai::FlowTriggers::RunService) }
    let(:run_service_2) { instance_double(::Ai::FlowTriggers::RunService) }

    before_all do
      project.add_developer(user)
      project.add_developer(service_account_1)
      project.add_developer(service_account_2)
      project.add_developer(service_account_3)
      project.add_developer(regular_user)
    end

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      stub_ee_application_setting(duo_features_enabled: true)
      allow(user).to receive(:allowed_to_use?).with(:duo_agent_platform, anything).and_return(true)
    end

    context 'when creating issue with multiple assignees with flow triggers' do
      let(:params) { { title: 'New issue', assignee_ids: [service_account_1.id, service_account_2.id] } }

      it 'triggers all matching flow trigger services' do
        expect(run_service_1).to receive(:execute).with({ input: an_instance_of(String), event: :assign, triggered_by_username: user.username })
        expect(run_service_2).to receive(:execute).with({ input: an_instance_of(String), event: :assign, triggered_by_username: user.username })

        expect(::Ai::FlowTriggers::RunService).to receive(:new)
          .with(project: project, current_user: user, resource: an_instance_of(Issue), flow_trigger: flow_trigger_1)
          .and_return(run_service_1)
        expect(::Ai::FlowTriggers::RunService).to receive(:new)
          .with(project: project, current_user: user, resource: an_instance_of(Issue), flow_trigger: flow_trigger_2)
          .and_return(run_service_2)

        expect(created_issue).to be_persisted
      end
    end

    context 'when creating issue with assignees with mixed trigger types' do
      let(:params) { { title: 'New issue', assignee_ids: [service_account_1.id, service_account_3.id] } }

      it 'only triggers assign event flow triggers' do
        expect(run_service_1).to receive(:execute).with({ input: an_instance_of(String), event: :assign, triggered_by_username: user.username })
        expect(::Ai::FlowTriggers::RunService).to receive(:new)
          .with(project: project, current_user: user, resource: an_instance_of(Issue), flow_trigger: flow_trigger_1)
          .and_return(run_service_1)

        expect(::Ai::FlowTriggers::RunService).not_to receive(:new)
          .with(project: project, current_user: user, resource: an_instance_of(Issue), flow_trigger: flow_trigger_3)

        expect(created_issue).to be_persisted
      end
    end

    context 'when creating issue with assignees without flow triggers' do
      let(:params) { { title: 'New issue', assignee_ids: [regular_user.id] } }

      it 'does not trigger any flow trigger services' do
        expect(::Ai::FlowTriggers::RunService).not_to receive(:new)

        expect(created_issue).to be_persisted
      end
    end

    context 'when creating issue without assignees' do
      let(:params) { { title: 'New issue' } }

      it 'does not trigger any flow trigger services' do
        expect(::Ai::FlowTriggers::RunService).not_to receive(:new)

        expect(created_issue).to be_persisted
      end
    end

    context 'when user cannot trigger AI flow' do
      let(:params) { { title: 'New issue', assignee_ids: [service_account_1.id, service_account_2.id] } }

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :trigger_ai_flow, project).and_return(false)
      end

      it 'does not trigger any flow trigger services' do
        expect(::Ai::FlowTriggers::RunService).not_to receive(:new)

        expect(created_issue).to be_persisted
      end
    end

    context 'when assigning via quick actions' do
      let(:params) { { title: 'New issue', description: "/assign @#{service_account_1.username} @#{service_account_2.username}" } }

      it 'triggers flow trigger services for assigned users' do
        expect(run_service_1).to receive(:execute).with({ input: an_instance_of(String), event: :assign, triggered_by_username: user.username })
        expect(run_service_2).to receive(:execute).with({ input: an_instance_of(String), event: :assign, triggered_by_username: user.username })

        expect(::Ai::FlowTriggers::RunService).to receive(:new)
          .with(project: project, current_user: user, resource: an_instance_of(Issue), flow_trigger: flow_trigger_1)
          .and_return(run_service_1)
        expect(::Ai::FlowTriggers::RunService).to receive(:new)
          .with(project: project, current_user: user, resource: an_instance_of(Issue), flow_trigger: flow_trigger_2)
          .and_return(run_service_2)

        expect(created_issue).to be_persisted
      end
    end

    context 'when created during a Duo workflow request' do
      let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }

      around do |example|
        ::Gitlab::ApplicationContext.with_context(duo_workflow_id: workflow.id.to_s) { example.run }
      end

      it 'records a created link from the workflow to the new work item' do
        expect { created_issue }.to change { Ai::DuoWorkflows::WorkflowWorkItem.count }.by(1)

        link = Ai::DuoWorkflows::WorkflowWorkItem.order(:id).last
        expect(link).to have_attributes(
          workflow: workflow,
          work_item_id: created_issue.id,
          link_type: 'created'
        )
      end

      context 'when no Duo workflow id is in the request context' do
        around do |example|
          ::Gitlab::ApplicationContext.with_context(duo_workflow_id: nil) { example.run }
        end

        it 'does not record a link' do
          expect { created_issue }.not_to change { Ai::DuoWorkflows::WorkflowWorkItem.count }
        end
      end

      context 'when the current user is not authorized to update the workflow' do
        let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: create(:user)) }

        it 'does not record a link' do
          expect { created_issue }.not_to change { Ai::DuoWorkflows::WorkflowWorkItem.count }
        end
      end

      it 'does not fail issue creation when linking raises' do
        allow(::Ai::DuoWorkflows::LinkArtifactService).to receive(:new).and_raise(StandardError)
        expect(::Gitlab::ErrorTracking).to receive(:track_exception)

        expect(created_issue).to be_persisted
      end
    end
  end
end
