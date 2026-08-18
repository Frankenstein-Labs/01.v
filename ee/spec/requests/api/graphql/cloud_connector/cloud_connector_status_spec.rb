# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying for Cloud Connector status', feature_category: :duo_setting do
  include GraphqlHelpers

  let(:query) do
    graphql_query_for(:cloudConnectorStatus, {}, <<~FIELDS)
      success
      probeResults {
        name
        success
        message
        details
        errors
      }
    FIELDS
  end

  before do
    # Need to stub this by default in order to allow expectations with specific
    # arguments in tests, as this method is called in various unrelated contexts.
    allow(::Gitlab::Saas).to receive(:feature_available?).and_call_original
  end

  context 'when the user is not authenticated' do
    it 'returns an error' do
      post_graphql(query, current_user: nil)

      expect_graphql_errors_to_include("The resource that you are attempting to access does not exist")
    end
  end

  context 'when the user is authenticated' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:errors) { ActiveModel::Errors.new(nil) }

    let(:service) { instance_double(CloudConnector::StatusChecks::StatusService, execute: service_response) }
    let(:probe_results) do
      [CloudConnector::StatusChecks::Probes::ProbeResult.new('test_probe', true, 'probed', [], errors)]
    end

    before do
      # Allow any other calls for permission checks.
      allow(::Ability).to receive(:allowed?).and_call_original
      # Only stub the one we're interested in explicitly.
      allow(::Ability).to receive(:allowed?)
        .with(current_user, :read_cloud_connector_status)
        .and_return(has_permission)

      # Stub all service calls since they may be performing network I/O.
      allow(CloudConnector::StatusChecks::StatusService).to receive(:new).and_return(service)
    end

    context 'when the user does not have the right permissions' do
      let(:has_permission) { false }
      let(:service_response) { ServiceResponse.success(message: 'OK', payload: { probe_results: probe_results }) }

      it 'returns an error' do
        post_graphql(query, current_user: current_user)

        expect_graphql_errors_to_include("The resource that you are attempting to access does not exist")
      end
    end

    context 'when the user has the right permissions' do
      let(:has_permission) { true }

      context 'when response is success' do
        let(:service_response) { ServiceResponse.success(message: 'OK', payload: { probe_results: probe_results }) }

        it 'returns successful status response' do
          post_graphql(query, current_user: current_user)

          expect(graphql_data['cloudConnectorStatus']).to include(
            'success' => true,
            'probeResults' => match_array([{
              'name' => 'test_probe', 'success' => true, 'message' => 'probed', 'errors' => [], 'details' => []
            }])
          )
        end
      end

      context 'when response is error' do
        let(:service_response) { ServiceResponse.error(message: 'NOK', payload: { probe_results: probe_results }) }

        before do
          allow(CloudConnector::StatusChecks::StatusService).to receive(:new).and_return(service)
        end

        it 'returns unsuccessful status response' do
          post_graphql(query, current_user: current_user)

          expect(graphql_data['cloudConnectorStatus']).to include(
            'success' => false,
            'probeResults' => match_array([{
              'name' => 'test_probe', 'success' => true, 'message' => 'probed', 'errors' => [], 'details' => []
            }])
          )
        end
      end

      context 'when on gitlab.com' do
        let(:service_response) { ServiceResponse.success(message: 'OK', payload: { probe_results: probe_results }) }

        before do
          allow(::Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(true)
        end

        it 'returns an error' do
          post_graphql(query, current_user: current_user)

          expect_graphql_errors_to_include("The resource that you are attempting to access does not exist")
        end
      end
    end
  end
end
