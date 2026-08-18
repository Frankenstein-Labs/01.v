# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a work item', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:developer) { create(:user, developer_of: group) }

  let(:mutation_response) { graphql_mutation_response(:work_item_create) }
  let(:widgets_response) { mutation_response['workItem']['widgets'] }
  let(:type_response) { mutation_response['workItem']['workItemType'] }

  before_all do
    # Ensure support bot user is created so creation doesn't count towards query limit
    # and we don't try to obtain an exclusive lease within a transaction.
    # See https://gitlab.com/gitlab-org/gitlab/-/issues/509629
    create(:support_bot)
  end

  context 'when user has permissions to create a work item' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(epics: true)
    end

    shared_examples 'creates work item with iteration widget' do
      let(:fields) do
        <<~FIELDS
          workItem {
            workItemType {
              name
            }
            widgets {
              type
              ... on WorkItemWidgetIteration {
                iteration {
                  id
                }
              }
            }
          }
          errors
        FIELDS
      end

      context 'when setting iteration on work item creation' do
        let_it_be(:cadence) { create(:iterations_cadence, group: group) }
        let_it_be(:iteration) { create(:iteration, iterations_cadence: cadence) }
        let(:task_type) { build(:work_item_system_defined_type, :task) }

        let(:input) do
          {
            title: 'new title',
            workItemTypeId: task_type.to_global_id.to_s,
            iterationWidget: { 'iterationId' => iteration.to_global_id.to_s }
          }
        end

        before do
          stub_licensed_features(epics: true, iterations: true)
        end

        it "sets the work item's iteration", :aggregate_failures do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.to change { WorkItem.count }.by(1)

          expect(response).to have_gitlab_http_status(:success)
          expect(type_response).to include({ 'name' => 'Task' })
          expect(widgets_response).to include(
            {
              'type' => 'ITERATION',
              'iteration' => { 'id' => iteration.to_global_id.to_s }
            }
          )
        end

        context 'when iterations feature is unavailable' do
          before do
            stub_licensed_features(epics: true, iterations: false)
          end

          # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/383322
          # We prefer to return an error rather than nil when authorization for an object fails.
          # Here the authorization fails due to the unavailability of the licensed feature.
          # Because the object to be authorized gets loaded via argument inside an InputObject,
          # we need to add an additional hook to Types::BaseInputObject so errors are raised.
          it 'returns nil' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to not_change { WorkItem.count }

            expect(mutation_response).to be_nil
          end
        end
      end

      context 'when creating a key result' do
        let_it_be(:parent) { create(:work_item, :objective, **container_params) }

        let(:key_result_type) { build(:work_item_system_defined_type, :key_result) }

        let(:fields) do
          <<~FIELDS
            workItem {
              id
              workItemType {
                name
              }
              widgets {
                type
                ... on WorkItemWidgetHierarchy {
                  parent {
                    id
                  }
                }
              }
            }
            errors
          FIELDS
        end

        let(:input) do
          {
            title: 'key result',
            workItemTypeId: key_result_type.to_global_id.to_s,
            hierarchyWidget: { 'parentId' => parent.to_global_id.to_s }
          }
        end

        context 'when okrs are available' do
          before do
            stub_licensed_features(epics: true, okrs: true)
          end

          it 'creates the work item' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { WorkItem.count }.by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(type_response).to include({ 'name' => 'Key Result' })
            expect(widgets_response).to include(
              {
                'parent' => { 'id' => parent.to_global_id.to_s },
                'type' => 'HIERARCHY'
              }
            )
          end
        end

        context 'when okrs are not available' do
          before do
            stub_licensed_features(epics: true, okrs: false)
          end

          it 'returns error' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to not_change(WorkItem, :count)

            expect(mutation_response['errors'])
              .to contain_exactly(/could not be found or is not accessible/)
            expect(mutation_response['workItem']).to be_nil
          end
        end
      end

      context 'when group_webhooks feature is available', :aggregate_failures do
        let(:task_type) { build(:work_item_system_defined_type, :task) }
        let(:input) do
          {
            title: 'new title',
            workItemTypeId: task_type.to_global_id.to_s
          }
        end

        before do
          stub_licensed_features(epics: true, group_webhooks: true)
          create(:group_hook, issues_events: true, group: group)
        end

        it 'creates a work item' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.to change { WorkItem.count }.by(1)

          expect(response).to have_gitlab_http_status(:success)
        end
      end
    end

    shared_examples 'creates work item with weight widget' do
      let(:issue_type) { build(:work_item_system_defined_type, :issue) }

      let(:fields) do
        <<~FIELDS
          workItem {
            workItemType {
              name
            }
            widgets {
              type
              ... on WorkItemWidgetWeight {
                weight
              }
            }
          }
          errors
        FIELDS
      end

      let(:input) do
        {
          title: 'new title',
          workItemTypeId: issue_type.to_global_id.to_s,
          weightWidget: { 'weight' => 5 }
        }
      end

      before do
        stub_licensed_features(issue_weights: true)
      end

      it "sets the work item's weight", :aggregate_failures do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { WorkItem.count }.by(1)

        expect(response).to have_gitlab_http_status(:success)
        expect(type_response).to include({ 'name' => 'Issue' })
        expect(widgets_response).to include(
          {
            'type' => 'WEIGHT',
            'weight' => 5
          }
        )
      end

      context 'when feature is not available' do
        before do
          stub_licensed_features(issue_weights: false)
        end

        it 'returns an error', :aggregate_failures do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.to not_change { WorkItem.count }

          expect(json_response['errors']).to include(
            a_hash_including(
              'message' => 'Following widget keys are not supported by Issue type: [:weight_widget]'
            )
          )
        end
      end
    end

    shared_examples 'creates work item with agent plan widget' do
      let(:issue_type) { build(:work_item_system_defined_type, :issue) }
      let(:plan_content) { '## Plan\n\nDo the thing.' }

      let(:fields) do
        <<~FIELDS
          workItem {
            workItemType {
              name
            }
            widgets {
              type
              ... on WorkItemWidgetAgentPlan {
                content
                contentHtml
              }
            }
          }
          errors
        FIELDS
      end

      let(:input) do
        {
          title: 'new title',
          workItemTypeId: issue_type.to_global_id.to_s,
          agentPlanWidget: { content: plan_content }
        }
      end

      before do
        stub_licensed_features(ai_workflows: true)
      end

      it "sets the work item's agent plan", :aggregate_failures do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { WorkItem.count }.by(1)

        expect(response).to have_gitlab_http_status(:success)
        expect(type_response).to include({ 'name' => 'Issue' })

        agent_plan_widget = widgets_response.find { |w| w['type'] == 'AGENT_PLAN' }
        expect(agent_plan_widget).to include('content' => plan_content)
        expect(agent_plan_widget['contentHtml']).to be_present
        expect(Nokogiri::HTML5.fragment(agent_plan_widget['contentHtml']).text).to include('Do the thing.')
      end

      context 'when feature is not available' do
        before do
          stub_licensed_features(ai_workflows: false)
        end

        it 'returns an error', :aggregate_failures do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.to not_change { WorkItem.count }

          expect(json_response['errors']).to include(
            a_hash_including(
              'message' => 'Following widget keys are not supported by Issue type: [:agent_plan_widget]'
            )
          )
        end
      end
    end

    shared_examples 'creates work item linked to a vulnerability' do
      let(:vulnerability) { create(:vulnerability, title: "First", project: project) }
      let_it_be(:issue_work_item_type) { build(:work_item_system_defined_type, :issue) }

      let(:work_item_type) { issue_work_item_type }

      let(:fields) do
        <<~FIELDS
          workItem {
            id
            workItemType {
              name
            }
          }
          errors
        FIELDS
      end

      let(:input) do
        {
          title: 'new title',
          workItemTypeId: work_item_type.to_global_id.to_s,
          vulnerabilityId: vulnerability.to_global_id.to_s
        }
      end

      before do
        stub_licensed_features(security_dashboard: true, epics: true)
      end

      it "links Issue work item to vulnerability", :aggregate_failures do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { WorkItem.count }.by(1)

        work_item_id = GlobalID.parse(mutation_response['workItem']['id']).model_id.to_i
        work_item = WorkItem.find(work_item_id)

        expect(response).to have_gitlab_http_status(:success)
        expect(type_response).to include({ 'name' => 'Issue' })
        expect(work_item.related_vulnerabilities).to include(vulnerability)
      end

      context 'with other work item types' do
        let_it_be(:task_work_item_type) { build(:work_item_system_defined_type, :task) }

        let(:work_item_type) { task_work_item_type }

        it "links Task work item to vulnerability", :aggregate_failures do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.to change { WorkItem.count }.by(1)

          work_item_id = GlobalID.parse(mutation_response['workItem']['id']).model_id.to_i
          work_item = WorkItem.find(work_item_id)

          expect(response).to have_gitlab_http_status(:success)
          expect(type_response).to include({ 'name' => 'Task' })
          expect(work_item.related_vulnerabilities).to include(vulnerability)
        end
      end

      context 'when feature is not available' do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it 'returns an error', :aggregate_failures do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.to not_change { WorkItem.count }

          expect(json_response['errors']).to include(
            a_hash_including(
              'message' => "The resource that you are attempting to access does not exist or you " \
                "don't have permission to perform this action"
            )
          )
        end
      end
    end

    context 'when creating work items in a project' do
      context 'with projectPath' do
        let_it_be(:container_params) { { project: project } }
        let(:mutation) { graphql_mutation(:workItemCreate, input.merge(projectPath: project.full_path), fields) }

        context 'with task type' do
          let(:work_item_type) { :task }

          it_behaves_like 'creates work item with iteration widget'
          it_behaves_like 'creates work item with weight widget'
          it_behaves_like 'creates work item with agent plan widget'
          it_behaves_like 'creates work item linked to a vulnerability'
        end

        context 'with epic type' do
          let(:epic_type) { build(:work_item_system_defined_type, :epic) }
          let(:work_item_type) { :epic }

          let(:fields) do
            <<~FIELDS
              workItem {
                workItemType {
                  name
                }
              }
              errors
            FIELDS
          end

          let(:input) do
            { title: "project epic WI", workItemTypeId: epic_type.to_gid.to_s }
          end

          context 'when epics licensed feature is available' do
            before do
              stub_licensed_features(epics: true)
            end

            it 'creates the work item epic' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
              end.to change { WorkItem.count }.by(1)

              expect(response).to have_gitlab_http_status(:success)
              expect(type_response).to include({ 'name' => 'Epic' })
            end

            context 'when project_work_item_epics feature flag is disabled' do
              before do
                stub_feature_flags(project_work_item_epics: false)
              end

              it 'return an error' do
                expect do
                  post_graphql_mutation(mutation, current_user: current_user)
                end.to not_change { WorkItem.count }

                expect_graphql_errors_to_include(
                  "The resource that you are attempting to access does not exist or " \
                    "you don't have permission to perform this action"
                )
              end
            end
          end

          context 'when epics licensed feature is not available' do
            before do
              stub_licensed_features(epics: false)
            end

            it 'return an error' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
              end.to not_change { WorkItem.count }

              expect_graphql_errors_to_include(
                "The resource that you are attempting to access does not exist or " \
                  "you don't have permission to perform this action"
              )
            end
          end
        end
      end

      context 'with namespacePath' do
        let_it_be(:container_params) { { project: project } }
        let(:mutation) { graphql_mutation(:workItemCreate, input.merge(namespacePath: project.full_path), fields) }
        let(:work_item_type) { :task }

        it_behaves_like 'creates work item with iteration widget'
        it_behaves_like 'creates work item with weight widget'
        it_behaves_like 'creates work item with agent plan widget'
        it_behaves_like 'creates work item linked to a vulnerability'
      end
    end

    context 'when creating work items in a group' do
      let_it_be(:container_params) { { namespace: group } }
      let(:mutation) { graphql_mutation(:workItemCreate, input.merge(namespacePath: group.full_path), fields) }
      let(:work_item_type) { :epic }
      let(:epic_type) { build(:work_item_system_defined_type, work_item_type) }

      it_behaves_like 'authorizing granular token permissions for GraphQL', :create_work_item do
        let(:user) { current_user }
        let(:boundary_object) { group }
        let(:mutation) do
          graphql_mutation(
            :workItemCreate,
            { title: 'Granular group work item',
              workItemTypeId: epic_type.to_gid.to_s,
              namespacePath: group.full_path },
            'errors'
          )
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      context 'when using resolve discussion in merge request arguments' do
        let_it_be(:merge_request) { create(:merge_request, source_project: project) }
        let(:mutation) do
          graphql_mutation(
            :workItemCreate,
            {
              title: 'some WI',
              workItemTypeId: epic_type.to_gid.to_s,
              namespacePath: group.full_path,
              discussions_to_resolve: { noteable_id: merge_request.to_gid.to_s }
            }
          )
        end

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(graphql_errors).to contain_exactly(
            hash_including(
              'message' => _('Only project level work items can be created to resolve noteable discussions')
            )
          )
        end
      end

      context 'with rolledup dates widget input' do
        before do
          stub_licensed_features(epics: true)
        end

        let(:fields) do
          <<~FIELDS
            workItem {
              workItemType {
                name
              }
              widgets {
                type
                  ... on WorkItemWidgetStartAndDueDate {
                    isFixed
                    rollUp
                    startDate
                    startDateSourcingWorkItem {
                      id
                    }
                    startDateSourcingMilestone {
                      id
                    }
                    dueDate
                    dueDateSourcingWorkItem {
                      id
                    }
                    dueDateSourcingMilestone {
                      id
                    }
                  }
              }
            }
            errors
          FIELDS
        end

        context "with fixed dates" do
          let(:start_date) { 5.days.ago.to_date }
          let(:due_date) { 5.days.from_now.to_date }

          let(:input) do
            {
              title: "some WI",
              workItemTypeId: build(:work_item_system_defined_type, work_item_type).to_gid.to_s,
              startAndDueDateWidget: {
                isFixed: true,
                startDate: start_date.to_s,
                dueDate: due_date.to_s
              }
            }
          end

          it "sets the work item's start and due date", :aggregate_failures do
            expect { post_graphql_mutation(mutation, current_user: current_user) }
              .to change { WorkItem.count }
              .by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(type_response).to include({ 'name' => work_item_type.to_s.capitalize })
            expect(widgets_response).to include(
              "type" => "START_AND_DUE_DATE",
              "isFixed" => true,
              "rollUp" => true,
              "dueDate" => due_date.to_s,
              "dueDateSourcingMilestone" => nil,
              "dueDateSourcingWorkItem" => nil,
              "startDate" => start_date.to_s,
              "startDateSourcingMilestone" => nil,
              "startDateSourcingWorkItem" => nil
            )
          end
        end
      end

      context 'with health status widget input' do
        let(:new_status) { 'onTrack' }
        let(:input) do
          {
            title: "some WI",
            workItemTypeId: build(:work_item_system_defined_type, work_item_type).to_gid.to_s,
            healthStatusWidget: { healthStatus: new_status }
          }
        end

        let(:fields) do
          <<~FIELDS
            workItem {
              workItemType {
                name
              }
              widgets {
                type
                ... on WorkItemWidgetHealthStatus {
                  healthStatus
                }
              }
            }
            errors
          FIELDS
        end

        context 'when issuable_health_status is licensed' do
          before do
            stub_licensed_features(epics: true, issuable_health_status: true)
          end

          it 'sets value for the health status widget' do
            expect { post_graphql_mutation(mutation, current_user: current_user) }.to change { WorkItem.count }.by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(type_response).to include({ 'name' => work_item_type.to_s.capitalize })
            expect(mutation_response['workItem']['widgets']).to include(
              {
                'healthStatus' => 'onTrack',
                'type' => 'HEALTH_STATUS'
              }
            )
          end
        end

        context 'when issuable_health_status is unlicensed' do
          before do
            stub_licensed_features(epics: true, issuable_health_status: false)
          end

          it 'returns an error' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to not_change { WorkItem.count }

            expect(mutation_response).to be_nil
            expect(graphql_errors).to include(a_hash_including(
              'message' => "Following widget keys are not supported by Epic type: [:health_status_widget]"
            ))
          end
        end
      end

      context 'with color widget input' do
        let(:new_color) { '#346465' }
        let(:input) do
          {
            title: "some WI",
            workItemTypeId: build(:work_item_system_defined_type, work_item_type).to_gid.to_s,
            colorWidget: { color: new_color }
          }
        end

        let(:fields) do
          <<~FIELDS
            workItem {
              workItemType {
                name
              }
              widgets {
                type
                ... on WorkItemWidgetColor {
                  color
                }
              }
            }
            errors
          FIELDS
        end

        context 'when epic_colors is licensed' do
          before do
            stub_licensed_features(epics: true, epic_colors: true)
          end

          it 'sets value for color widget' do
            expect { post_graphql_mutation(mutation, current_user: current_user) }.to change { WorkItem.count }.by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(type_response).to include({ 'name' => work_item_type.to_s.capitalize })
            expect(mutation_response['workItem']['widgets']).to include(
              {
                'color' => new_color,
                'type' => 'COLOR'
              }
            )
          end
        end

        context 'when epic_colors is unlicensed' do
          before do
            stub_licensed_features(epics: true, epic_colors: false)
          end

          it 'returns an error' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to not_change { WorkItem.count }

            expect(mutation_response).to be_nil
            expect(graphql_errors).to include(a_hash_including(
              'message' => "Following widget keys are not supported by Epic type: [:color_widget]"
            ))
          end
        end
      end

      context 'with assignees widget input containing multiple assignees' do
        let_it_be(:assignees) do
          [
            create(:user, developer_of: project, name: 'BBB'),
            create(:user, developer_of: project, name: 'AAA')
          ]
        end

        let(:fields) do
          <<~FIELDS
            workItem {
              workItemType {
                name
              }
              widgets {
                type
                ... on WorkItemWidgetAssignees {
                  assignees {
                    nodes {
                      id
                      name
                      username
                    }
                  }
                }
              }
            }
            errors
          FIELDS
        end

        let(:input) do
          {
            title: 'some WI',
            workItemTypeId: build(:work_item_system_defined_type, work_item_type).to_gid.to_s,
            assigneesWidget: { 'assigneeIds' => assignees.map(&:to_gid).map(&:to_s) }
          }
        end

        context 'when multiple_issue_assignees is licensed' do
          before do
            stub_licensed_features(epics: true, multiple_issue_assignees: true)
          end

          it "sets the work item's assignees" do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { WorkItem.count }.by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(type_response).to include({ 'name' => work_item_type.to_s.capitalize })
            expect(widgets_response).to include(
              {
                'assignees' => { 'nodes' => [
                  {
                    'id' => assignees[1].to_gid.to_s,
                    'username' => assignees[1].username,
                    'name' => assignees[1].name
                  },
                  {
                    'id' => assignees[0].to_gid.to_s,
                    'username' => assignees[0].username,
                    'name' => assignees[0].name
                  }
                ] },
                'type' => 'ASSIGNEES'
              }
            )
          end
        end

        context 'when multiple_issue_assignees is unlicensed' do
          before do
            stub_licensed_features(
              epics: true,
              related_epics: true,
              multiple_issue_assignees: false
            )
          end

          it 'assigns only the first assignee' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { WorkItem.count }.by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(type_response).to include({ 'name' => work_item_type.to_s.capitalize })
            expect(widgets_response).to include(
              {
                'assignees' => { 'nodes' => [
                  { 'id' => assignees[0].to_gid.to_s, 'username' => assignees[0].username, 'name' => assignees[0].name }
                ] },
                'type' => 'ASSIGNEES'
              }
            )
          end
        end
      end

      context 'with linked items widget input' do
        using RSpec::Parameterized::TableSyntax

        let_it_be(:items) { create_list(:work_item, 2, project: project) }

        let(:fields) do
          <<~FIELDS
          workItem {
            workItemType {
              name
            }
            widgets {
              type
              ... on WorkItemWidgetLinkedItems {
                linkedItems {
                  nodes {
                    linkType
                    workItem { id }
                  }
                }
              }
            }
          }
          errors
          FIELDS
        end

        let(:input) do
          {
            title: 'some WI',
            workItemTypeId: build(:work_item_system_defined_type, work_item_type).to_gid.to_s,
            linkedItemsWidget: { 'workItemsIds' => items.map(&:to_gid).map(&:to_s), 'linkType' => link_type }
          }
        end

        where(:link_type, :expected_type) do
          'BLOCKS'     | 'blocks'
          'BLOCKED_BY' | 'is_blocked_by'
        end

        with_them do
          context 'when licensed feature `blocked_work_items` is available', :aggregate_failures do
            before do
              stub_licensed_features(
                epics: true,
                related_epics: true,
                blocked_work_items: true
              )
            end

            it 'creates a work item with linked items using the corrcet type' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
              end.to change { WorkItem.count }.by(1)
                 .and change { WorkItems::RelatedWorkItemLink.count }.by(2)

              expect(response).to have_gitlab_http_status(:success)
              expect(type_response).to include({ 'name' => 'Epic' })
              expect(widgets_response).to include(
                {
                  'linkedItems' => { 'nodes' => match_array([
                    { 'linkType' => expected_type, "workItem" => { "id" => items[1].to_global_id.to_s } },
                    { 'linkType' => expected_type, "workItem" => { "id" => items[0].to_global_id.to_s } }
                  ]) },
                  'type' => 'LINKED_ITEMS'
                }
              )
            end
          end

          context 'when licensed feature `blocked_work_items` is not available' do
            before do
              stub_licensed_features(
                epics: true,
                related_epics: true,
                blocked_work_items: false
              )
            end

            it 'returns an error' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
              end.to change { WorkItem.count }.by(1)
                 .and not_change { WorkItems::RelatedWorkItemLink.count }

              expect(mutation_response['errors'])
                .to contain_exactly('Blocked work items are not available for the current subscription tier')
            end
          end
        end
      end

      context 'on type validations' do
        let(:fields) do
          <<~FIELDS
            workItem {
              workItemType {
                name
              }
            }
            errors
          FIELDS
        end

        context 'when type is not Epic' do
          let(:input) do
            { title: "task WI", workItemTypeId: build(:work_item_system_defined_type, :task).to_gid.to_s }
          end

          it_behaves_like 'a mutation that returns top-level errors', errors: [
            Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR
          ]
        end

        context 'when type is Epic' do
          let(:input) do
            { title: "task WI",
              workItemTypeId: build(:work_item_system_defined_type, work_item_type).to_gid.to_s }
          end

          it 'creates the work item epic' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { WorkItem.count }.by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(type_response).to include({ 'name' => 'Epic' })
          end
        end
      end
    end
  end

  context 'when user lacks permissions to create work item type' do
    let_it_be(:current_user) { create(:user, guest_of: group) }

    let(:input) do
      { title: 'epic WI', workItemTypeId: build(:work_item_system_defined_type, :epic).to_gid.to_s }
    end

    let(:fields) do
      <<~FIELDS
        workItem {
          workItemType {
            name
          }
        }
        errors
      FIELDS
    end

    before do
      stub_licensed_features(epics: true)
    end

    shared_examples 'return authorization error' do
      specify do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to not_change { WorkItem.count }

        expect_graphql_errors_to_include(
          "The resource that you are attempting to access does not exist or " \
            "you don't have permission to perform this action"
        )
      end
    end

    context 'when creating epics in a group' do
      let_it_be(:container_params) { { namespace: group } }
      let(:mutation) { graphql_mutation(:workItemCreate, input.merge(namespacePath: group.full_path), fields) }

      it_behaves_like 'return authorization error'
    end

    context 'when creating epics in a project' do
      let_it_be(:container_params) { { project: project } }
      let(:mutation) { graphql_mutation(:workItemCreate, input.merge(projectPath: project.full_path), fields) }

      it_behaves_like 'return authorization error'
    end
  end

  context 'with custom fields widget input' do
    include_context 'with group configured with custom fields'

    let_it_be(:project) { create(:project, group: group, developers: [developer]) }

    let(:mutation) { graphql_mutation(:workItemCreate, input, 'workItem { id }') }
    let(:date) { generate(:sequential_date).to_date }

    let(:input) do
      {
        'namespacePath' => project.full_path,
        'workItemTypeId' => issue_type.to_gid.to_s,
        'title' => 'New work item',
        'customFieldsWidget' => [
          { 'customFieldId' => global_id_of(number_field), 'numberValue' => 100 },
          { 'customFieldId' => global_id_of(text_field), 'textValue' => 'TEST' },
          { 'customFieldId' => global_id_of(date_field), 'dateValue' => date.to_s },
          { 'customFieldId' => global_id_of(multi_select_field), 'selectedOptionIds' => [
            global_id_of(multi_select_option_1), global_id_of(multi_select_option_3)
          ] }
        ]
      }
    end

    before do
      stub_licensed_features(custom_fields: true)
    end

    it 'creates the work item with custom field values', :aggregate_failures do
      post_graphql_mutation(mutation, current_user: developer)

      expect(response).to have_gitlab_http_status(:success)

      work_item_id = GlobalID.parse(mutation_response['workItem']['id']).model_id.to_i

      expect(WorkItems::NumberFieldValue.last).to have_attributes(
        work_item_id: work_item_id, custom_field_id: number_field.id, value: 100
      )
      expect(WorkItems::TextFieldValue.last).to have_attributes(
        work_item_id: work_item_id, custom_field_id: text_field.id, value: 'TEST'
      )
      expect(WorkItems::DateFieldValue.last).to have_attributes(
        work_item_id: work_item_id, custom_field_id: date_field.id, value: date
      )
      expect(WorkItems::SelectFieldValue.last(2)).to contain_exactly(
        have_attributes({
          work_item_id: work_item_id,
          custom_field_id: multi_select_field.id,
          custom_field_select_option_id: multi_select_option_1.id
        }),
        have_attributes({
          work_item_id: work_item_id,
          custom_field_id: multi_select_field.id,
          custom_field_select_option_id: multi_select_option_3.id
        })
      )
    end
  end

  context 'with status widget input' do
    let_it_be(:work_item_type) { build(:work_item_system_defined_type, :task) }
    let(:status) { build(:work_item_system_defined_status, :in_progress) }
    let(:status_gid) { status.to_gid.to_s }
    let(:expected_error_message) do
      "Following widget keys are not supported by #{work_item_type.name} type: [:status_widget]"
    end

    let(:current_user) { developer }
    let(:mutation) { graphql_mutation(:workItemCreate, input, 'workItem { id }') }
    let(:input) do
      {
        'namespacePath' => project.full_path,
        'workItemTypeId' => work_item_type.to_gid.to_s,
        'title' => 'New work item',
        'statusWidget' => {
          'status' => status_gid
        }
      }
    end

    it_behaves_like 'work item mutation with status widget with error'

    context 'when work_item_status feature is licensed' do
      before do
        stub_licensed_features(work_item_status: true)
      end

      it_behaves_like 'successful work item mutation with status widget'

      context 'with custom status' do
        let!(:lifecycle) do
          create(:work_item_custom_lifecycle, namespace: group, work_item_types: [work_item_type])
        end

        let(:status) { create(:work_item_custom_status, name: 'In review', lifecycles: [lifecycle]) }

        it_behaves_like 'successful work item mutation with status widget'
      end

      it_behaves_like 'work item status widget mutation rejects invalid inputs'

      context 'when work item type does not support status widget' do
        before do
          stub_all_work_item_widgets(status: false)
        end

        let_it_be(:work_item_type) { build(:work_item_system_defined_type, :requirement) }

        it_behaves_like 'work item mutation with status widget with error'
      end
    end
  end

  context 'with custom work item types' do
    let_it_be(:custom_type) { create(:work_item_custom_type, namespace: group) }
    let_it_be(:custom_type_in_organization) do
      create(:work_item_custom_type, :with_organization, organization: project.organization)
    end

    let(:fields) do
      <<~FIELDS
        workItem {
          id
          title
          workItemType {
            name
          }
          widgets {
            type
          }
        }
        errors
      FIELDS
    end

    let(:namespace) { project }
    let(:type_to_be_used) { custom_type }
    let(:input) do
      {
        title: 'Custom typed work item',
        workItemTypeId: type_to_be_used.to_global_id.to_s,
        namespacePath: namespace.full_path
      }
    end

    let(:current_user) { developer }
    let(:mutation) { graphql_mutation(:workItemCreate, input, fields) }

    before do
      stub_licensed_features(epics: true, configurable_work_item_types: true)
      stub_saas_features(namespace_scoped_work_item_types: true)
    end

    shared_examples 'returns a graphql error' do
      it 'returns a resource not available error' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response).to be_nil
        expect(graphql_errors).to include(
          a_hash_including('message' => a_string_including('does not exist or you don\'t have permission'))
        )
      end
    end

    shared_examples 'returns a custom type error' do
      it 'returns an error and does not create a work item' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.not_to change { WorkItem.count }

        expect(mutation_response).to be_nil
        expect(graphql_errors).to include(
          a_hash_including('message' => a_string_including(error_message))
        )
      end
    end

    shared_examples 'creates a work item' do
      it 'creates a work item with correct type' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { WorkItem.count }.by(1)

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to be_blank
        expect(mutation_response['workItem']['workItemType']['name']).to eq(type_to_be_used.name)
        expect(mutation_response['errors']).to be_empty
      end
    end

    include_examples 'creates a work item'

    context 'when creating with a converted type' do
      let_it_be(:converted_type) { create(:work_item_custom_type, :converted_from_issue, namespace: group) }

      let(:type_to_be_used) { converted_type }

      include_examples 'creates a work item'
    end

    context 'when creating in a group' do
      let(:namespace) { group }
      let(:error_message) { 'Custom types can only be created in projects' }

      include_examples 'returns a custom type error'
    end

    context 'when creating with an organization level type' do
      let(:type_to_be_used) { custom_type_in_organization }

      include_examples 'returns a graphql error'
    end

    context 'when configurable_work_item_types license is not available' do
      let(:error_message) { 'Configurable work item types are not available' }

      before do
        stub_licensed_features(epics: true, configurable_work_item_types: false)
      end

      include_examples 'returns a custom type error'
    end

    context 'when custom type is from a different namespace' do
      let_it_be(:other_group) { create(:group) }
      let_it_be(:other_custom_type) { create(:work_item_custom_type, namespace: other_group) }

      let(:type_to_be_used) { other_custom_type }

      include_examples 'returns a graphql error'
    end
  end

  describe '.authorization' do
    it 'allows ai_workflows scope token' do
      expect(Mutations::WorkItems::Create.authorization.permitted_scopes).to include(:ai_workflows)
    end
  end

  describe 'work_item field with :ai_workflows scope' do
    let(:mutation_class) { Mutations::WorkItems::Create }

    %w[errors workItem].each do |field_name|
      it "includes :ai_workflows scope for the #{field_name} field" do
        field = mutation_class.fields[field_name]
        expect(field.instance_variable_get(:@scopes)).to include(:ai_workflows)
      end
    end
  end
end
