# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SubscriptionPortal::Clients::Graphql, :without_license, feature_category: :subscription_management do
  let(:client) { Gitlab::SubscriptionPortal::Client }
  let(:graphql_url) { ::Gitlab::Routing.url_helpers.subscription_portal_graphql_url }

  before do
    stub_env('GITLAB_QA_USER_AGENT', nil)
  end

  shared_examples 'connectivity problems calling the endpoint' do
    let_it_be(:connectivity_error) { "HTTP status code: 403" }

    let_it_be(:connectivity_error_response) do
      {
        success: false,
        data: {
          errors: connectivity_error
        }
      }.with_indifferent_access
    end

    it 'returns a failure response and logs the error when failed to call endpoint' do
      expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).with(
        a_kind_of(Gitlab::SubscriptionPortal::Client::ResponseError),
        query: params[:query],
        response: connectivity_error_response[:data]
      )

      expect(client).to receive(:http_post).with('graphql', headers, params).and_return(connectivity_error_response)

      expect(subject).to eq(success: false, errors: connectivity_error)
    end
  end

  describe '#activate' do
    let(:license_key) { 'license_key' }

    it 'returns success' do
      expect(client).to receive(:execute_graphql_query).and_return(
        {
          success: true,
          data: {
            "data" => {
              "cloudActivationActivate" => {
                "licenseKey" => license_key,
                "errors" => [],
                "newSubscription" => true,
                "futureSubscriptions" => []
              }
            }
          }
        }
      )

      result = client.activate('activation_code_abc', automated: false)

      expect(result).to eq(
        {
          license_key: license_key,
          success: true,
          future_subscriptions: [],
          new_subscription: true
        }
      )
    end

    context 'when there are future subscriptions' do
      it 'returns success' do
        future_date = 4.days.from_now.to_date

        expect(client).to receive(:execute_graphql_query).and_return(
          {
            success: true,
            data: {
              "data" => {
                "cloudActivationActivate" => {
                  "licenseKey" => license_key,
                  "errors" => [],
                  "futureSubscriptions" => [
                    {
                      "cloudLicenseEnabled" => true,
                      "offlineCloudLicenseEnabled" => false,
                      "plan" => "ultimate",
                      "name" => "User Example",
                      "company" => "Example Inc",
                      "email" => "user@example.com",
                      "startsAt" => future_date.to_s,
                      "expiresAt" => (future_date + 1.year).to_s,
                      "usersInLicenseCount" => 10
                    }
                  ],
                  "newSubscription" => false
                }
              }
            }
          }
        )

        result = client.activate('activation_code_abc', automated: false)

        expected_result = {
          license_key: license_key,
          success: true,
          future_subscriptions: [
            {
              "cloud_license_enabled" => true,
              "offline_cloud_license_enabled" => false,
              "plan" => "ultimate",
              "name" => "User Example",
              "company" => "Example Inc",
              "email" => "user@example.com",
              "starts_at" => future_date.to_s,
              "expires_at" => (future_date + 1.year).to_s,
              "users_in_license_count" => 10
            }
          ],
          new_subscription: false
        }

        expect(result).to eq(expected_result)
      end
    end

    context 'when the activation code is invalid' do
      it 'returns failure' do
        expect(client).to receive(:execute_graphql_query).and_return(
          {
            success: true,
            data: {
              "data" => {
                "cloudActivationActivate" => {
                  "licenseKey" => nil,
                  "errors" => ["invalid activation code"],
                  "futureSubscriptions" => [],
                  "newSubscription" => nil
                }
              }
            }
          }
        )

        result = client.activate('activation_code_abc', automated: false)

        expect(result).to eq({ errors: ["invalid activation code"], success: false })
      end
    end

    context 'when remote server returns error' do
      it 'returns connectivity error' do
        response = Net::HTTPServerError.new(1.0, '500', 'Internal Server Error')
        gitlab_http_response = instance_double(
          HTTParty::Response,
          code: response.code,
          parsed_response: { errors: 'Internal Server Error' },
          response: response,
          body: 'body'
        )
        allow(Gitlab::HTTP).to receive(:post).and_return(gitlab_http_response)
        allow(Gitlab::ErrorTracking).to receive(:log_exception)

        result = client.activate('activation_code_abc', automated: false)

        expect(result).to eq({ errors: described_class::CONNECTIVITY_ERROR, success: false })
        expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(
          instance_of(::Gitlab::SubscriptionPortal::Client::ResponseError),
          { status: response.code, errors: "HTTP status code: #{response.code}" }
        )
      end
    end

    context 'when the remote server is unreachable' do
      it 'returns connectivity error' do
        stub_request(:any, graphql_url).to_timeout
        allow(Gitlab::ErrorTracking).to receive(:log_exception)

        result = client.activate('activation_code_abc', automated: false)

        expect(result).to eq({ errors: described_class::CONNECTIVITY_ERROR, success: false })
        expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(kind_of(Timeout::Error))
      end
    end
  end

  describe '#subscription_next_term_start_date' do
    let(:query) do
      <<~GQL
        query($namespaceId: ID!) {
          subscription(namespaceId: $namespaceId) {
            nextTermStartDate
          }
        }
      GQL
    end

    it 'returns success' do
      expected_args = {
        query: query,
        variables: {
          namespaceId: 'namespace-id'
        }
      }

      expected_response = {
        success: true,
        data: {
          "data" => {
            "subscription" => {
              "nextTermStartDate" => "2024-11-01"
            }
          }
        }
      }

      expect(client).to receive(:execute_graphql_query).with(expected_args).and_return(expected_response)

      result = client.subscription_next_term_start_date('namespace-id')

      expect(result).to eq({ success: true, next_term_start_date: "2024-11-01" })
    end

    it 'returns failure' do
      error = "some error"
      expect(client).to receive(:execute_graphql_query).and_return(
        {
          success: false,
          data: {
            errors: error
          }
        }
      )

      result = client.subscription_next_term_start_date('failing-namespace-id')

      expect(result).to eq({ success: false, errors: error })
    end

    context 'with no namespace_id' do
      it 'returns failure' do
        expect(client).not_to receive(:execute_graphql_query)

        expect(client.subscription_next_term_start_date(nil)).to eq(
          { success: false, errors: 'Must provide a namespace ID' }
        )
      end
    end
  end

  describe '#subscription_seat_usage_alerts_eligibility' do
    let(:query) do
      <<~GQL
        query($namespaceId: ID!) {
          subscription(namespaceId: $namespaceId) {
            isEligibleForSeatUsageAlerts
          }
        }
      GQL
    end

    it 'returns success when the subscription can be found' do
      expected_args = {
        query: query,
        variables: {
          namespaceId: 'namespace-id'
        }
      }

      expected_response = {
        success: true,
        data: {
          "data" => {
            "subscription" => {
              "isEligibleForSeatUsageAlerts" => true
            }
          }
        }
      }

      expect(client).to receive(:execute_graphql_query).with(expected_args).and_return(expected_response)

      result = client.subscription_seat_usage_alerts_eligibility('namespace-id')

      expect(result).to eq({ success: true, eligible_for_seat_usage_alerts: true })
    end

    it 'returns failure when the subscription cannot be found' do
      error = "some error"
      expect(client).to receive(:execute_graphql_query).and_return(
        {
          success: false,
          data: {
            errors: error
          }
        }
      )

      result = client.subscription_seat_usage_alerts_eligibility('failing-namespace-id')

      expect(result).to eq({ success: false, errors: error })
    end

    context 'with no namespace_id' do
      it 'returns failure' do
        expect(client).not_to receive(:execute_graphql_query)

        expect(client.subscription_seat_usage_alerts_eligibility(nil))
          .to eq({ success: false, errors: 'Must provide a namespace ID' })
      end
    end

    context 'when there is a network connectivity error' do
      it 'returns an error response' do
        allow(client).to receive(:execute_graphql_query).and_raise(HTTParty::Error)
        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(kind_of(HTTParty::Error))

        request = client.subscription_seat_usage_alerts_eligibility('namespace-id')

        expect(request).to eq({ success: false, errors: "CONNECTIVITY_ERROR" })
      end
    end
  end

  describe '#get_plans' do
    subject { client.get_plans(tags: ['test-plan-id']) }

    let(:headers) do
      {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "X-Admin-Email" => "gl_com_api@gitlab.com",
        "X-Admin-Token" => "customer_admin_token",
        "User-Agent" => "GitLab/#{Gitlab::VERSION}"
      }
    end

    let(:params) do
      {
        variables: { tags: ['test-plan-id'] },
        query: <<~GQL
          query getPlans($tags: [PlanTag!]) {
            plans(planTags: $tags) {
              id
            }
          }
        GQL
      }
    end

    context 'when the request is successful' do
      it 'returns the data' do
        response = { success: true, data: { 'data' => { 'plans' => [{ 'id' => 1 }, { 'id' => 3 }] } } }

        expect(client).to receive(:http_post).with('graphql', headers, params).and_return(response)

        expect(subject).to eq(success: true, data: [{ 'id' => 1 }, { 'id' => 3 }])
      end
    end

    context 'when the request is unsuccessful' do
      it 'returns a failure response and logs the error' do
        response = {
          success: true,
          data: {
            "data" => { "plans" => nil },
            "errors" => [
              {
                "message" => "You must be logged in to access this resource",
                "locations" => [{ "line" => 2, "column" => 3 }],
                "path" => ["getPlans"]
              }
            ]
          }
        }

        expect(Gitlab::ErrorTracking)
          .to receive(:track_and_raise_for_dev_exception)
                .with(
                  a_kind_of(Gitlab::SubscriptionPortal::Client::ResponseError),
                  query: params[:query],
                  response: response[:data]
                )

        expect(client).to receive(:http_post).with('graphql', headers, params).and_return(response)

        error = {
          "locations" => [{ "column" => 3, "line" => 2 }],
          "message" => "You must be logged in to access this resource",
          "path" => ["getPlans"]
        }
        expect(subject).to eq(success: false, errors: [error])
      end
    end

    include_examples 'connectivity problems calling the endpoint'
  end

  describe '#filter_purchase_eligible_namespaces' do
    subject(:filter_purchase_eligible_namespaces) do
      client.filter_purchase_eligible_namespaces(
        [user_namespace, group_namespace, subgroup],
        plan_id: plan_id,
        any_self_service_plan: any_self_service_plan
      )
    end

    let_it_be(:user) { create(:user) }
    let_it_be(:plan_id) { 'test-plan' }
    let_it_be(:any_self_service_plan) { true }
    let_it_be(:user_namespace) { user.namespace }
    let_it_be(:group_namespace) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group_namespace) }

    let(:headers) do
      {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "X-Admin-Email" => "gl_com_api@gitlab.com",
        "X-Admin-Token" => "customer_admin_token",
        "User-Agent" => "GitLab/#{Gitlab::VERSION}"
      }
    end

    let(:variables) do
      {
        planId: plan_id,
        eligibleForPurchase: true,
        namespaces: [
          {
            id: user_namespace.id,
            parentId: nil,
            plan: "default",
            trial: false,
            kind: 'user',
            membersCountWithDescendants: nil
          },
          {
            id: group_namespace.id,
            parentId: nil,
            plan: "default",
            trial: false,
            kind: 'group',
            membersCountWithDescendants: 0
          },
          {
            id: subgroup.id,
            parentId: group_namespace.id,
            plan: "default",
            trial: false,
            kind: 'group',
            membersCountWithDescendants: 0
          }
        ]
      }
    end

    let(:params) do
      {
        variables: variables,
        query: <<~GQL
          query FilterEligibleNamespaces($namespaces: [GitlabNamespaceInput!]!, $planId: ID, $eligibleForPurchase: Boolean) {
            namespaceEligibility(namespaces: $namespaces, planId: $planId, eligibleForPurchase: $eligibleForPurchase) {
              id
            }
          }
        GQL
      }
    end

    context 'when the response is successful' do
      it 'returns the namespace data', :aggregate_failures do
        response = {
          success: true,
          data: {
            'data' => {
              'namespaceEligibility' => [
                { 'id' => 1 }, { 'id' => 3 }
              ]
            }
          }
        }

        expect(client).to receive(:http_post).with('graphql', headers, params).and_return(response)

        expect(subject).to eq(success: true, data: [{ 'id' => 1 }, { 'id' => 3 }])
      end

      it 'returns success with empty array when no namespaces are eligible', :aggregate_failures do
        response = {
          success: true,
          data: {
            'data' => {
              'namespaceEligibility' => []
            }
          }
        }

        expect(client).to receive(:http_post).with('graphql', headers, params).and_return(response)

        expect(subject).to eq(success: true, data: [])
      end
    end

    context 'when the response is unsuccessful' do
      it 'returns the error message', :aggregate_failures do
        response = {
          success: true,
          data: {
            "data" => {
              "namespaceEligibility" => nil
            },
            "errors" => [
              {
                "message" => "You must be logged in to access this resource",
                "locations" => [{ "line" => 2, "column" => 3 }],
                "path" => ["namespaceEligibility"]
              }
            ]
          }
        }

        expect(Gitlab::ErrorTracking)
          .to receive(:track_and_raise_for_dev_exception)
                .with(
                  a_kind_of(Gitlab::SubscriptionPortal::Client::ResponseError),
                  query: params[:query], response: response[:data])

        expect(client).to receive(:http_post).with('graphql', headers, params).and_return(response)

        error = {
          "locations" => [{ "column" => 3, "line" => 2 }],
          "message" => "You must be logged in to access this resource",
          "path" => ["namespaceEligibility"]
        }
        expect(subject).to eq(success: false, errors: [error])
      end
    end

    include_examples 'connectivity problems calling the endpoint'
  end

  describe '#update_namespace_name' do
    subject(:update_request) do
      client.update_namespace_name('namespace id', 'namespace name')
    end

    it 'returns success' do
      expect(client).to receive(:execute_graphql_query).and_return(
        {
          success: true,
          data: {
            'data' => {
              'orderNamespaceNameUpdate' => {
                'errors' => []
              }
            }
          }
        }
      )

      expect(update_request).to eq({ success: true })
    end

    it 'returns top level errors' do
      top_level_errors = ['Validation error', 'Errors in query execution']

      expect(client).to receive(:execute_graphql_query).and_return(
        {
          success: true,
          data: {
            'errors' => top_level_errors
          }
        }
      )

      expect(update_request).to eq({ errors: top_level_errors, success: false })
    end

    it 'returns errors as data' do
      errors_as_data = ['error updating the name']

      expect(client).to receive(:execute_graphql_query).and_return(
        {
          success: true,
          data: {
            'data' => {
              'orderNamespaceNameUpdate' => {
                'errors' => errors_as_data
              }
            }
          }
        }
      )

      expect(update_request).to eq({ errors: errors_as_data, success: false })
    end

    it 'returns connectivity error when remote server returns error' do
      response = Net::HTTPServerError.new(1.0, '500', 'Internal Server Error')
      gitlab_http_response = instance_double(
        HTTParty::Response,
        code: response.code,
        parsed_response: { errors: 'Internal Server Error' },
        response: response,
        body: {}
      )
      allow(Gitlab::HTTP).to receive(:post).and_return(gitlab_http_response)
      allow(Gitlab::ErrorTracking).to receive(:log_exception)

      expect(update_request).to eq({ errors: described_class::CONNECTIVITY_ERROR, success: false })

      expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(
        instance_of(::Gitlab::SubscriptionPortal::Client::ResponseError),
        { status: response.code, errors: "HTTP status code: #{response.code}" }
      )
    end

    it 'returns connectivity error when the remote server is unreachable' do
      stub_request(:any, graphql_url).to_timeout
      allow(Gitlab::ErrorTracking).to receive(:log_exception)

      expect(update_request).to eq({ errors: described_class::CONNECTIVITY_ERROR, success: false })
      expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(kind_of(Timeout::Error))
    end
  end

  describe '#send_seat_overage_notification' do
    context 'when the subscription portal response is successful' do
      it 'returns successfully' do
        group = create(:group)
        owner_1 = create(:user)
        owner_2 = create(:user)

        group.add_owner(owner_1)
        group.add_owner(owner_2)

        expected_query_params = {
          variables: {
            namespaceId: group.id,
            maxSeatsUsed: 10,
            groupOwners: [
              { id: owner_1.id, email: owner_1.email, fullName: owner_1.name },
              { id: owner_2.id, email: owner_2.email, fullName: owner_2.name }
            ]
          },
          query: <<~GQL
            mutation($namespaceId: Int!, $maxSeatsUsed: Int!, $groupOwners: [GitlabEmailsUserInput!]!) {
              sendSeatOverageNotificationEmail(input: {
                glNamespaceId: $namespaceId,
                maxSeatsUsed: $maxSeatsUsed,
                groupOwners: $groupOwners
              }) {
                errors
              }
            }
          GQL
        }

        portal_response = {
          success: true,
          data: {
            "data" => {
              "sendSeatOverageNotificationEmail" => {
                "errors" => []
              }
            }
          }
        }

        expect(client).to receive(:execute_graphql_query).with(expected_query_params).and_return(portal_response)

        request = client.send_seat_overage_notification(
          group: group,
          max_seats_used: 10
        )

        expect(request).to eq({ success: true })
      end
    end

    context 'when the subscription portal response is unsuccessful' do
      it 'returns an error response' do
        expected_query_params = {
          variables: { namespaceId: 1, maxSeatsUsed: nil, groupOwners: [] },
          query: <<~GQL
            mutation($namespaceId: Int!, $maxSeatsUsed: Int!, $groupOwners: [GitlabEmailsUserInput!]!) {
              sendSeatOverageNotificationEmail(input: {
                glNamespaceId: $namespaceId,
                maxSeatsUsed: $maxSeatsUsed,
                groupOwners: $groupOwners
              }) {
                errors
              }
            }
          GQL
        }

        message = "Argument 'maxSeatsUsed' on InputObject 'SendSeatOverageNotificationEmailInput' has an " \
                  "invalid value (null). Expected type 'Int!'."
        portal_response = {
          success: true,
          data: {
            "errors" => [
              {
                "message" => message,
                "locations" => [{ line: 2, column: 43 }],
                "path" => %w[mutation sendSeatOverageNotificationEmail input maxSeatsUsed],
                "extensions" => {
                  "code" => "argumentLiteralsIncompatible",
                  "typeName" => "InputObject",
                  "argumentName" => "maxSeatsUsed"
                }
              }
            ]
          }
        }

        expect(client).to receive(:execute_graphql_query).with(expected_query_params).and_return(portal_response)

        request = client.send_seat_overage_notification(group: build(:group, id: 1), max_seats_used: nil)

        expect(request[:success]).to be false
        expect(request[:errors]).not_to be_empty
      end
    end

    context 'when there is a network connectivity error' do
      it 'returns an error response' do
        allow(client).to receive(:execute_graphql_query).and_raise(HTTParty::Error)
        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(kind_of(HTTParty::Error))

        request = client.send_seat_overage_notification(group: build(:group), max_seats_used: nil)

        expect(request).to eq({ success: false, errors: "CONNECTIVITY_ERROR" })
      end
    end
  end

  describe '#send_seat_overage_notification_batch' do
    let(:query_params) do
      {
        variables: { namespaces: [] },
        query: <<~GQL
          mutation($namespaces: [NamespaceSeatOverageInput!]) {
            sendSeatOverageNotificationEmail(input: {
              namespaces: $namespaces
            }) {
              errors
            }
          }
        GQL
      }
    end

    context 'when the subscription portal response is successful' do
      it 'returns successfully' do
        portal_response = {
          success: true,
          data: {
            "data" => {
              "sendSeatOverageNotificationEmail" => {
                "errors" => []
              }
            }
          }
        }

        expect(client).to receive(:execute_graphql_query).with(query_params).and_return(portal_response)

        request = client.send_seat_overage_notification_batch([])

        expect(request).to eq({ success: true })
      end
    end

    context 'when the subscription portal response is unsuccessful' do
      it 'returns an error response' do
        message = "Argument 'maxSeatsUsed' on InputObject 'SendSeatOverageNotificationEmailInput' has an " \
                  "invalid value (null). Expected type 'Int!'."
        portal_response = {
          success: true,
          data: {
            "errors" => [
              {
                "message" => message,
                "locations" => [{ line: 2, column: 43 }],
                "path" => %w[mutation sendSeatOverageNotificationEmail input maxSeatsUsed],
                "extensions" => {
                  "code" => "argumentLiteralsIncompatible",
                  "typeName" => "InputObject",
                  "argumentName" => "maxSeatsUsed"
                }
              }
            ]
          }
        }

        expect(client).to receive(:execute_graphql_query).with(query_params).and_return(portal_response)

        request = client.send_seat_overage_notification_batch([])

        expect(request[:success]).to be false
        expect(request[:errors]).not_to be_empty
      end
    end

    context 'when there is a network connectivity error' do
      it 'returns an error response' do
        allow(client).to receive(:execute_graphql_query).and_raise(HTTParty::Error)
        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(kind_of(HTTParty::Error))

        request = client.send_seat_overage_notification_batch(group: build(:group), max_seats_used: nil)

        expect(request).to eq({ success: false, errors: "CONNECTIVITY_ERROR" })
      end
    end
  end

  describe '#get_cloud_connector_access_data' do
    before do
      allow(CloudConnector).to receive(:headers).with(nil).and_return(
        {
          'X-Gitlab-Host-Name' => "localhost",
          'X-Gitlab-Instance-Id' => "cloud_connector_test_uuid",
          'X-Gitlab-Realm' => "self-managed",
          'X-Gitlab-Version' => "15.0.1"
        }
      )
    end

    let_it_be(:license_key) { build(:gitlab_license, :cloud).export }
    let_it_be(:token) { 'stored-token' }
    let_it_be(:expires_at) { Date.current.iso8601 }

    let(:headers) do
      {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "User-Agent" => "GitLab/#{Gitlab::VERSION}",
        "X-Gitlab-Realm" => "self-managed",
        "X-Gitlab-Host-Name" => "localhost",
        "X-Gitlab-Instance-Id" => "cloud_connector_test_uuid",
        "X-Gitlab-Version" => "15.0.1"
      }
    end

    let(:params) do
      {
        variables: { licenseKey: license_key, gitlabVersion: Gitlab::VERSION },
        query: <<~GQL
          query cloudConnectorAccess($licenseKey: String!, $gitlabVersion: String!) {
            cloudConnectorAccess(licenseKey: $licenseKey, gitlabVersion: $gitlabVersion) {
              serviceToken {
                token
                expiresAt
              }
              catalog
            }
          }
        GQL
      }
    end

    subject { client.get_cloud_connector_access_data(license_key) }

    context 'when the request is successful' do
      let_it_be(:catalog) do
        {
          "backend_services" => [
            {
              "name" => "ai_gateway_agent",
              "project_url" => "unknown",
              "group" => "group::ai framework",
              "jwt_aud" => "gitlab-ai-gateway-agent"
            }
          ],
          "unit_primitives" => [
            {
              "name" => "agent_quick_actions",
              "description" => "Quick actions for agent.",
              "group" => "group::duo_chat",
              "feature_category" => "duo_chat",
              "backend_services" => ["ai_gateway_agent"],
              "license_types" => ["ultimate"]
            }
          ],
          "add_ons" => [
            { "name" => "duo_enterprise" },
            { "name" => "duo_pro" }
          ],
          "license_types" => [
            { "name" => "premium" },
            { "name" => "ultimate" }
          ]
        }
      end

      it 'returns the data' do
        response = {
          success: true,
          data: {
            'data' => {
              'cloudConnectorAccess' => {
                'serviceToken' => {
                  'token' => token,
                  'expiresAt' => expires_at
                },
                'catalog' => catalog
              }
            }
          }
        }

        expect(client).to receive(:http_post).with('graphql', headers, params).and_return(response)

        expect(subject).to eq(success: true, token: token, expires_at: expires_at, catalog: catalog)
      end
    end

    context 'when the response contains an error' do
      it 'returns a failure response and logs the error' do
        response = {
          success: true,
          data: {
            "data" => { "serviceToken" => nil },
            "errors" => [
              {
                "message" => "You must be logged in to access this resource",
                "locations" => [{ "line" => 2, "column" => 3 }],
                "path" => ["serviceToken"]
              }
            ]
          }
        }

        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).with(
          a_kind_of(Gitlab::SubscriptionPortal::Client::ResponseError),
          query: params[:query],
          response: response[:data]
        )

        expect(client).to receive(:http_post).with('graphql', headers, params).and_return(response)

        error = {
          "locations" => [{ "column" => 3, "line" => 2 }],
          "message" => "You must be logged in to access this resource",
          "path" => ["serviceToken"]
        }
        expect(subject).to eq(success: false, errors: [error])
      end
    end

    include_examples 'connectivity problems calling the endpoint'
  end
end
