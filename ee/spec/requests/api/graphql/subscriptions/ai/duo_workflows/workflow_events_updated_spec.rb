# frozen_string_literal: true

require "spec_helper"

RSpec.describe 'Subscriptions::Ai::DuoWorkflows::WorkflowEventsUpdated', feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:user) { create(:user) }
  let(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }
  let(:checkpoint) { create(:duo_workflows_checkpoint, :ui_chat_log, project: project, workflow: workflow) }
  let(:subscription_query) do
    <<~SUBSCRIPTION
      subscription {
        workflowEventsUpdated(workflowId: \"#{workflow.to_gid}\") {
          checkpoint
          metadata
          errors
          workflowStatus
          executionStatus
          duoMessages {
            content
            messageType
            status
            toolInfo
            timestamp
            correlationId
            role
          }
        }
      }
    SUBSCRIPTION
  end

  let(:subscribe) do
    mock_channel = Graphql::Subscriptions::ActionCable::MockActionCable.get_mock_channel
    GitlabSchema.execute(subscription_query, context: { current_user: user, channel: mock_channel })
    mock_channel
  end

  let(:updated_workflow) { graphql_dig_at(graphql_data(response[:result]), :workflowEventsUpdated) }

  before do
    stub_const('GitlabSchema', Graphql::Subscriptions::ActionCable::MockGitlabSchema)
    Graphql::Subscriptions::ActionCable::MockActionCable.clear_mocks
  end

  subject(:response) do
    subscription_response do
      GraphqlTriggers.workflow_events_updated(checkpoint)
    end
  end

  context 'when duo workflow is not available' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(false)
    end

    it 'does not receive any data' do
      expect(response).to be_nil
    end
  end

  context "when duo workflow is available" do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
      allow_any_instance_of(User).to receive_messages(allowed_to_use?: true, allowed_to_use_for_resource?: true)
      # rubocop:enable RSpec/AnyInstanceOf
    end

    context 'when user is unauthorized' do
      before_all do
        project.add_guest(user)
      end

      it 'does not receive any data' do
        expect(response).to be_nil
      end
    end

    context 'when user is a compliance reviewer with :read_agent_artifacts but not the workflow owner' do
      let_it_be(:reviewer) { create(:user) }
      let_it_be(:reviewer_role) do
        create(:member_role, :guest, :read_agent_artifacts, namespace: group)
      end

      let_it_be(:reviewer_membership) do
        create(:group_member, :guest, member_role: reviewer_role, user: reviewer, group: group)
      end

      let(:subscription_query) do
        <<~SUBSCRIPTION
          subscription {
            workflowEventsUpdated(workflowId: \"#{workflow.to_gid}\") {
              checkpoint
            }
          }
        SUBSCRIPTION
      end

      let(:subscribe) do
        mock_channel = Graphql::Subscriptions::ActionCable::MockActionCable.get_mock_channel
        GitlabSchema.execute(subscription_query, context: { current_user: reviewer, channel: mock_channel })
        mock_channel
      end

      before do
        stub_licensed_features(
          custom_roles: true,
          project_level_compliance_dashboard: true,
          group_level_compliance_dashboard: true
        )
      end

      it 'does not receive any data' do
        expect(response).to be_nil
      end
    end

    context 'when user is authorized' do
      let_it_be(:chat_log) do
        [{ "content" => "hi", "correlationId" => nil, "messageType" => "user", "role" => nil, "status" => "success",
           "timestamp" => "2025-11-25T21:10:57.734182+00:00", "toolInfo" => "null" }]
      end

      before_all do
        project.add_developer(user)
      end

      it 'receives updated workflow_event data' do
        # Reload to compare against jsonb-normalized values: Postgres
        # jsonb reorders keys (by length, then alpha), so an in-memory
        # factory Hash and the API's serialized response only line up
        # after a DB round-trip.
        stored = checkpoint.reload
        expect(Gitlab::Json.safe_parse(updated_workflow['checkpoint'])).to eq(stored.checkpoint)
        expect(Gitlab::Json.safe_parse(updated_workflow['metadata'])).to eq(stored.metadata)
        expect(updated_workflow['errors']).to eq([])
        expect(updated_workflow['workflowStatus']).to eq('CREATED')
        expect(updated_workflow['executionStatus']).to eq('Created')
        expect(updated_workflow['duoMessages']).to eq(chat_log)
      end

      context 'when duo_features_enabled settings is turned off' do
        before do
          project.project_setting.update!(duo_features_enabled: false)
        end

        it 'does not receive any data' do
          expect(response).to be_nil
        end
      end
    end
  end

  def subscription_response
    subscription_channel = subscribe
    yield
    subscription_channel.mock_broadcasted_messages.first
  end
end
