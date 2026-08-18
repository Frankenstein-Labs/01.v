# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GraphqlTriggers, feature_category: :api do
  describe '.issuable_weight_updated' do
    let_it_be(:work_item) { create(:work_item) }

    it 'triggers the issuable_weight_updated subscription' do
      expect(GitlabSchema.subscriptions).to receive(:trigger).with(
        :issuable_weight_updated,
        { issuable_id: work_item.to_gid },
        work_item
      ).and_call_original

      ::GraphqlTriggers.issuable_weight_updated(work_item)
    end

    it 'triggers the issuable_iteration_updated subscription' do
      expect(GitlabSchema.subscriptions).to receive(:trigger).with(
        :issuable_iteration_updated,
        { issuable_id: work_item.to_gid },
        work_item
      ).and_call_original

      ::GraphqlTriggers.issuable_iteration_updated(work_item)
    end

    describe '.issuable_health_status_updated' do
      it 'triggers the issuable_health_status_updated subscription' do
        expect(GitlabSchema.subscriptions).to receive(:trigger).with(
          :issuable_health_status_updated,
          { issuable_id: work_item.to_gid },
          work_item
        ).and_call_original

        ::GraphqlTriggers.issuable_health_status_updated(work_item)
      end
    end

    describe '.issuable_epic_updated' do
      it 'triggers the issuable_epic_updated subscription' do
        expect(GitlabSchema.subscriptions).to receive(:trigger).with(
          :issuable_epic_updated,
          { issuable_id: work_item.to_gid },
          work_item
        )

        ::GraphqlTriggers.issuable_epic_updated(work_item)
      end
    end
  end

  describe '.ai_completion_response' do
    let_it_be(:user) { create(:user) }
    let(:message) { build(:ai_message, user: user, resource: user) }

    subject(:ai_completion_response) { described_class.ai_completion_response(message) }

    before do
      allow(GitlabSchema.subscriptions).to receive(:trigger).and_call_original
    end

    it 'triggers ai_completion_response with subscription arguments' do
      expect(GitlabSchema.subscriptions).to receive(:trigger).with(
        :ai_completion_response,
        { user_id: message.user.to_gid, ai_action: message.ai_action.to_s },
        message.to_h
      ).and_call_original

      ai_completion_response
    end

    it 'triggers duplicated ai_completion_response with resource argument' do
      expect(GitlabSchema.subscriptions).to receive(:trigger).with(
        :ai_completion_response,
        { user_id: message.user.to_gid, resource_id: message.resource&.to_gid },
        message.to_h
      ).and_call_original

      ai_completion_response
    end

    context 'with client_subscription_id' do
      let(:message) { build(:ai_message, user: user, resource: user, role: role, client_subscription_id: 'foo') }
      let(:role) { 'assistant' }

      it 'triggers ai_completion_response with client subscription id' do
        expect(GitlabSchema.subscriptions).to receive(:trigger).with(
          :ai_completion_response,
          {
            user_id: message.user.to_gid,
            ai_action: message.ai_action.to_s,
            client_subscription_id: message.client_subscription_id
          },
          message.to_h
        ).and_call_original

        ai_completion_response
      end

      context 'for user messages' do
        let(:role) { 'user' }

        it 'triggers ai_completion_response without client subscription id' do
          expect(GitlabSchema.subscriptions).to receive(:trigger).with(
            :ai_completion_response,
            {
              user_id: message.user.to_gid,
              ai_action: message.ai_action.to_s
            },
            message.to_h
          ).and_call_original

          ai_completion_response
        end
      end
    end
  end

  describe '.workflow_events_updated' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user, developer_of: project) }
    let(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }
    let(:checkpoint) { create(:duo_workflows_checkpoint, project: project, workflow: workflow) }

    it 'triggers the workflow_events_updated subscription' do
      expect(GitlabSchema.subscriptions).to receive(:trigger).with(
        :workflow_events_updated,
        { workflow_id: checkpoint.workflow.to_gid },
        checkpoint
      ).and_call_original

      ::GraphqlTriggers.workflow_events_updated(checkpoint)
    end
  end

  describe '.cd_rollout_updated', feature_category: :continuous_delivery do
    let_it_be(:application) { create(:cd_application) }
    let_it_be(:rollout) { create(:cd_rollout, application: application) }
    let_it_be(:rollout_environment) { create(:cd_rollout_environment, rollout: rollout) }
    let_it_be(:thread) { create(:ai_conversation_thread) }

    it 'triggers the cd_rollout_updated subscription' do
      expect(GitlabSchema.subscriptions).to receive(:trigger).with(
        :cd_rollout_updated,
        { application_id: application.to_gid },
        {
          rollout: rollout,
          rollout_environment: rollout_environment,
          thread: thread,
          reason: :deployment_failed
        }
      ).and_call_original

      ::GraphqlTriggers.cd_rollout_updated(
        rollout, :deployment_failed, rollout_environment: rollout_environment, thread: thread
      )
    end

    it 'defaults rollout_environment and thread to nil' do
      expect(GitlabSchema.subscriptions).to receive(:trigger).with(
        :cd_rollout_updated,
        { application_id: application.to_gid },
        {
          rollout: rollout,
          rollout_environment: nil,
          thread: nil,
          reason: :deployment_created
        }
      ).and_call_original

      ::GraphqlTriggers.cd_rollout_updated(rollout, :deployment_created)
    end
  end

  describe '.cd_application_health_updated', feature_category: :continuous_delivery do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:application) { create(:cd_application, organization: organization) }

    it 'triggers the cd_application_health_updated subscription' do
      expect(GitlabSchema.subscriptions).to receive(:trigger).with(
        :cd_application_health_updated,
        { organization_id: organization.to_gid },
        application
      ).and_call_original

      ::GraphqlTriggers.cd_application_health_updated(application)
    end
  end

  describe '.cd_service_updated', feature_category: :continuous_delivery do
    let_it_be(:application) { create(:cd_application) }
    let_it_be(:service) { create(:cd_service, application: application) }

    it 'triggers the cd_service_updated subscription' do
      expect(GitlabSchema.subscriptions).to receive(:trigger).with(
        :cd_service_updated,
        { application_id: application.to_gid },
        service
      ).and_call_original

      ::GraphqlTriggers.cd_service_updated(service)
    end
  end

  describe '.cd_deployment_updated', feature_category: :continuous_delivery do
    let_it_be(:application) { create(:cd_application) }
    let_it_be(:service) { create(:cd_service, application: application) }
    let_it_be(:deployment) { create(:cd_deployment, service: service) }

    it 'triggers the cd_deployment_updated subscription' do
      expect(GitlabSchema.subscriptions).to receive(:trigger).with(
        :cd_deployment_updated,
        { application_id: application.to_gid },
        deployment
      ).and_call_original

      ::GraphqlTriggers.cd_deployment_updated(deployment)
    end
  end

  describe '.security_policy_project_created' do
    subject(:trigger) do
      described_class.security_policy_project_created(container, status, security_policy_project, errors)
    end

    let_it_be(:container) { create(:project) }
    let_it_be(:security_policy_project) { create(:project) }
    let(:status) { :success }
    let(:errors) { [] }

    it 'triggers the subscription' do
      expect(GitlabSchema.subscriptions).to receive(:trigger).with(
        :security_policy_project_created,
        { full_path: container.full_path },
        { status: status, project: security_policy_project, errors: errors, error_message: nil }
      )

      trigger
    end

    context 'with errors' do
      let(:errors) { %w[error1 error2] }

      it 'triggers the subscription with errors' do
        expect(GitlabSchema.subscriptions).to receive(:trigger).with(
          :security_policy_project_created,
          { full_path: container.full_path },
          { status: status, project: security_policy_project, errors: errors, error_message: 'error1 error2' }
        )

        trigger
      end
    end
  end
end
