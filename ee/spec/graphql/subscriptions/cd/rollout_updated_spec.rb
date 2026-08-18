# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Subscriptions::Cd::RolloutUpdated, feature_category: :continuous_delivery do
  include GraphqlHelpers
  include ::Graphql::Subscriptions::Cd::RolloutUpdated::Helper

  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be_with_reload(:rollout) { create(:cd_rollout, application: application) }

  let(:current_user) { nil }
  let(:subscribe) { cd_rollout_updated_subscription(application, current_user) }

  before do
    stub_const('GitlabSchema', Graphql::Subscriptions::ActionCable::MockGitlabSchema)
    Graphql::Subscriptions::ActionCable::MockActionCable.clear_mocks
  end

  subject(:response) do
    subscription_response do
      GraphqlTriggers.cd_rollout_updated(rollout, :deployment_failed)
    end
  end

  context 'when unauthorized' do
    it 'does not receive any data' do
      expect(response).to be_nil
    end
  end

  context 'when authorized' do
    let_it_be(:authorized_user) { create(:organization_user, :owner, organization: organization).user }
    let(:current_user) { authorized_user }

    let_it_be(:other_application) { create(:cd_application, organization: organization) }
    let_it_be(:other_rollout) { create(:cd_rollout, application: other_application) }

    let(:subscription_data) do
      graphql_dig_at(graphql_data(response[:result]), :cdRolloutUpdated)
    end

    it 'receives the rollout update' do
      expect(subscription_data).to include(
        'reason' => 'DEPLOYMENT_FAILED',
        'rollout' => { 'id' => rollout.to_global_id.to_s },
        'rolloutEnvironment' => nil,
        'thread' => nil
      )
    end

    context 'with a rollout_environment and thread' do
      let_it_be(:rollout_environment) { create(:cd_rollout_environment, rollout: rollout) }
      let_it_be(:thread) { create(:ai_conversation_thread, user: authorized_user) }

      subject(:response) do
        subscription_response do
          GraphqlTriggers.cd_rollout_updated(
            rollout, :deployment_created, rollout_environment: rollout_environment, thread: thread
          )
        end
      end

      it 'receives the rollout environment and thread' do
        expect(subscription_data).to include(
          'reason' => 'DEPLOYMENT_CREATED',
          'rollout' => { 'id' => rollout.to_global_id.to_s },
          'rolloutEnvironment' => { 'id' => rollout_environment.to_global_id.to_s },
          'thread' => { 'id' => thread.to_global_id.to_s }
        )
      end
    end

    context 'when update is for a different application id' do
      subject(:response) do
        subscription_response do
          GraphqlTriggers.cd_rollout_updated(other_rollout, :deployment_failed)
        end
      end

      it 'does not receive any data' do
        expect(response).to be_nil
      end
    end
  end
end
