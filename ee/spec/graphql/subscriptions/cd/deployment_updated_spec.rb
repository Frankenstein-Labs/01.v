# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Subscriptions::Cd::DeploymentUpdated, feature_category: :continuous_delivery do
  include GraphqlHelpers
  include ::Graphql::Subscriptions::Cd::DeploymentUpdated::Helper

  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:service) { create(:cd_service, application: application) }
  let_it_be(:deployment) { create(:cd_deployment, service: service) }

  let(:current_user) { nil }
  let(:subscribe) { cd_deployment_updated_subscription(application, current_user) }

  before do
    stub_const('GitlabSchema', Graphql::Subscriptions::ActionCable::MockGitlabSchema)
    Graphql::Subscriptions::ActionCable::MockActionCable.clear_mocks
  end

  subject(:response) do
    subscription_response do
      GraphqlTriggers.cd_deployment_updated(deployment)
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
    let_it_be(:other_service) { create(:cd_service, application: other_application) }
    let_it_be(:other_deployment) { create(:cd_deployment, service: other_service) }

    let(:subscription_data) do
      graphql_dig_at(graphql_data(response[:result]), :cdDeploymentUpdated)
    end

    it 'receives the updated deployment' do
      expect(subscription_data).to include(
        'id' => deployment.to_global_id.to_s,
        'state' => deployment.state.upcase
      )
    end

    context 'when update is for a different application id' do
      subject(:response) do
        subscription_response do
          GraphqlTriggers.cd_deployment_updated(other_deployment)
        end
      end

      it 'does not receive any data' do
        expect(response).to be_nil
      end
    end
  end
end
