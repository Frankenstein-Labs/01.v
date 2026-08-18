# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Subscriptions::Cd::ApplicationHealthUpdated, feature_category: :continuous_delivery do
  include GraphqlHelpers
  include ::Graphql::Subscriptions::Cd::ApplicationHealthUpdated::Helper

  let_it_be(:organization) { create(:organization) }
  let_it_be_with_reload(:application) { create(:cd_application, organization: organization) }

  let(:current_user) { nil }
  let(:subscribe) { cd_application_health_updated_subscription(organization, current_user) }

  before do
    stub_const('GitlabSchema', Graphql::Subscriptions::ActionCable::MockGitlabSchema)
    Graphql::Subscriptions::ActionCable::MockActionCable.clear_mocks
  end

  subject(:response) do
    subscription_response do
      GraphqlTriggers.cd_application_health_updated(application)
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

    let_it_be(:other_organization) { create(:organization) }
    let_it_be(:other_application) { create(:cd_application, organization: other_organization) }

    let(:subscription_data) do
      graphql_dig_at(graphql_data(response[:result]), :cdApplicationHealthUpdated)
    end

    it 'receives the updated application' do
      expect(subscription_data).to include(
        'id' => application.to_global_id.to_s,
        'name' => application.name
      )
    end

    context 'when update is for a different organization id' do
      subject(:response) do
        subscription_response do
          GraphqlTriggers.cd_application_health_updated(other_application)
        end
      end

      it 'does not receive any data' do
        expect(response).to be_nil
      end
    end
  end
end
