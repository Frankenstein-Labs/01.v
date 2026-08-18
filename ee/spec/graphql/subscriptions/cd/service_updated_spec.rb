# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Subscriptions::Cd::ServiceUpdated, feature_category: :continuous_delivery do
  include GraphqlHelpers
  include ::Graphql::Subscriptions::Cd::ServiceUpdated::Helper

  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:service) { create(:cd_service, application: application) }

  let(:current_user) { nil }
  let(:subscribe) { cd_service_updated_subscription(application, current_user) }

  before do
    stub_const('GitlabSchema', Graphql::Subscriptions::ActionCable::MockGitlabSchema)
    Graphql::Subscriptions::ActionCable::MockActionCable.clear_mocks
  end

  subject(:response) do
    subscription_response do
      GraphqlTriggers.cd_service_updated(service)
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

    let(:subscription_data) do
      graphql_dig_at(graphql_data(response[:result]), :cdServiceUpdated)
    end

    it 'receives the updated service' do
      expect(subscription_data).to include(
        'id' => service.to_global_id.to_s,
        'name' => service.name
      )
    end

    context 'when update is for a different application id' do
      subject(:response) do
        subscription_response do
          GraphqlTriggers.cd_service_updated(other_service)
        end
      end

      it 'does not receive any data' do
        expect(response).to be_nil
      end
    end
  end
end
