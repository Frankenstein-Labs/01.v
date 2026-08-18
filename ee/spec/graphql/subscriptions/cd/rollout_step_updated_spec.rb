# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Subscriptions::Cd::RolloutStepUpdated, feature_category: :continuous_delivery do
  include GraphqlHelpers
  include ::Graphql::Subscriptions::Cd::RolloutStepUpdated::Helper

  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:version_set) { create(:cd_version_set, application: application) }
  let_it_be(:rollout) { create(:cd_rollout, version_set: version_set) }
  let_it_be(:step) { create(:cd_rollout_step, rollout: rollout) }

  let(:current_user) { nil }
  let(:subscribe) { cd_rollout_step_updated_subscription(rollout, current_user) }

  before do
    stub_const('GitlabSchema', Graphql::Subscriptions::ActionCable::MockGitlabSchema)
    Graphql::Subscriptions::ActionCable::MockActionCable.clear_mocks
  end

  subject(:response) do
    subscription_response do
      GraphqlTriggers.cd_rollout_step_updated(step)
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

    # A separate application (rather than reusing `version_set`), since only one
    # non-terminal rollout is allowed per application at a time.
    let_it_be(:other_application) { create(:cd_application, organization: organization) }
    let_it_be(:other_version_set) { create(:cd_version_set, application: other_application) }
    let_it_be(:other_rollout) { create(:cd_rollout, version_set: other_version_set) }
    let_it_be(:other_step) { create(:cd_rollout_step, rollout: other_rollout) }

    let(:subscription_data) do
      graphql_dig_at(graphql_data(response[:result]), :cdRolloutStepUpdated)
    end

    it 'receives the updated step' do
      expect(subscription_data).to include(
        'id' => step.to_global_id.to_s,
        'state' => step.state.upcase
      )
    end

    context 'when update is for a step on a different rollout' do
      subject(:response) do
        subscription_response do
          GraphqlTriggers.cd_rollout_step_updated(other_step)
        end
      end

      it 'does not receive any data' do
        expect(response).to be_nil
      end
    end
  end
end
