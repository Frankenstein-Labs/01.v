# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SubscriptionPortal::SubscriptionUsageClient, feature_category: :consumables_cost_management do
  let(:graphql_url) { ::Gitlab::Routing.url_helpers.subscription_portal_graphql_url }
  let(:params) do
    { query: query, variables: { instanceId: Gitlab::GlobalAnonymousId.instance_id }.merge(variables) }
  end

  let(:headers) do
    {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "User-Agent" => "GitLab/#{Gitlab::VERSION}"
    }.merge(admin_headers || {})
  end

  let(:start_date) { '2025-10-01' }
  let(:end_date) { '2025-10-31' }

  subject(:client) do
    described_class.new(
      namespace_id: namespace_id,
      license_key: license_key,
      start_date: start_date,
      end_date: end_date
    )
  end

  shared_examples 'performs request with correct params' do
    it 'perform post request with correct params' do
      expect(::Gitlab::HTTP).to receive(:post).with(
        graphql_url,
        headers: headers,
        body: params.to_json
      ).and_return(instance_double(
        HTTParty::Response,
        response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
        parsed_response: portal_response
      ))

      request
    end
  end

  shared_examples 'returns successfully' do
    it 'returns a successful response' do
      expect(::Gitlab::HTTP).to receive(:post).with(
        graphql_url,
        headers: headers,
        body: params.to_json
      ).and_return(instance_double(
        HTTParty::Response,
        response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
        parsed_response: portal_response
      ))

      expect(request).to eq(expected_response)
    end
  end

  shared_examples 'raises error on unsuccessful subscription portal response' do
    it 'raises an error from subscription portal' do
      response = instance_double(
        HTTParty::Response,
        response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
        parsed_response: {
          success: false,
          data: {
            errors: 'some error'
          }
        }
      )

      expect(Gitlab::ErrorTracking).to receive(:track_and_raise_exception).with(
        a_kind_of(described_class::ResponseError),
        query: query,
        response: response.parsed_response
      ).and_call_original

      expect(::Gitlab::HTTP).to receive(:post).with(
        graphql_url,
        headers: headers,
        body: params.to_json
      ).and_return(response)

      expect { request }.to raise_error(described_class::ResponseError, 'Received an error from CustomerDot')
    end

    it 'raises an error when subscription portal is not available' do
      http_response = instance_double(
        HTTParty::Response,
        response: Net::HTTPServiceUnavailable.new(1.0, '503', 'Service Unavailable')
      )

      expect(Gitlab::ErrorTracking).to receive(:track_and_raise_exception).with(
        a_kind_of(described_class::ResponseError),
        query: query,
        response: { data: { errors: 'Service Unavailable' } }
      ).and_call_original

      expect(::Gitlab::HTTP).to receive(:post).with(
        graphql_url,
        headers: headers,
        body: params.to_json
      ).and_return(http_response)

      expect { request }.to raise_error(described_class::ResponseError, 'Received an error from CustomerDot')
    end
  end

  shared_context 'for self-managed request' do
    let(:admin_headers) { nil }
    let(:namespace_id) { nil }
    let(:license_key) { 'license_key' }

    include_examples 'performs request with correct params'
    include_examples 'returns successfully'
    include_examples 'raises error on unsuccessful subscription portal response'
  end

  shared_context 'for gitlab.com request' do
    let(:namespace_id) { 1234 }
    let(:license_key) { nil }
    let(:admin_headers) do
      {
        "X-Admin-Email" => "gl_com_api@gitlab.com",
        "X-Admin-Token" => "customer_admin_token"
      }
    end

    include_examples 'performs request with correct params'
    include_examples 'returns successfully'
    include_examples 'raises error on unsuccessful subscription portal response'
  end

  describe '#get_metadata' do
    let(:request) { client.get_metadata }
    let(:query) { described_class::GET_METADATA_QUERY }
    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              startDate: "2025-10-01",
              endDate: "2025-10-31",
              enabled: true,
              isOutdatedClient: false,
              lastEventTransactionAt: "2025-10-01T16:19:59Z",
              overageTermsAccepted: true,
              canAcceptOverageTerms: true,
              dapPromoEnabled: false,
              usageDashboardPath: "/subscriptions/A-S00012345/usage"
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        subscriptionUsage: {
          startDate: "2025-10-01",
          endDate: "2025-10-31",
          enabled: true,
          isOutdatedClient: false,
          lastEventTransactionAt: "2025-10-01T16:19:59Z",
          overageTermsAccepted: true,
          canAcceptOverageTerms: true,
          dapPromoEnabled: false,
          usageDashboardPath: "/subscriptions/A-S00012345/usage"
        }
      }
    end

    include_context 'for self-managed request' do
      let(:variables) do
        { licenseKey: license_key, startDate: start_date, endDate: end_date, gitlabVersion: Gitlab::VERSION }
      end
    end

    include_context 'for gitlab.com request' do
      let(:variables) do
        { namespaceId: namespace_id, startDate: start_date, endDate: end_date, gitlabVersion: Gitlab::VERSION }
      end
    end
  end

  describe '#get_subscription_usage' do
    let(:request) { client.get_subscription_usage({ sort: :date_asc, limit: 30 }) }
    let(:query) { described_class::GET_SUBSCRIPTION_USAGE_QUERY }
    let(:credits_used) { 287.45 }
    let(:daily_average) { 123.45 }
    let(:daily_usage) { [{ date: '2025-10-01', creditsUsed: 123.45 }] }

    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              creditsUsed: credits_used,
              dailyAverage: daily_average,
              dailyUsage: daily_usage
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        subscriptionUsage: {
          creditsUsed: credits_used,
          dailyAverage: daily_average,
          dailyUsage: daily_usage
        }
      }
    end

    include_context 'for self-managed request' do
      let(:variables) do
        {
          licenseKey: license_key,
          startDate: start_date,
          endDate: end_date,
          sort: 'DATE_ASC',
          limit: 30
        }
      end
    end

    include_context 'for gitlab.com request' do
      let(:variables) do
        {
          namespaceId: namespace_id,
          startDate: start_date,
          endDate: end_date,
          sort: 'DATE_ASC',
          limit: 30
        }
      end
    end

    context 'when called without args' do
      let(:request) { client.get_subscription_usage }

      include_context 'for self-managed request' do
        let(:variables) do
          {
            licenseKey: license_key,
            startDate: start_date,
            endDate: end_date
          }
        end
      end

      include_context 'for gitlab.com request' do
        let(:variables) do
          {
            namespaceId: namespace_id,
            startDate: start_date,
            endDate: end_date
          }
        end
      end
    end

    context 'when flow_types are provided' do
      let(:request) { client.get_subscription_usage(sort: :date_asc, limit: 30, flow_types: %w[chat]) }

      include_context 'for self-managed request' do
        let(:variables) do
          {
            licenseKey: license_key,
            startDate: start_date,
            endDate: end_date,
            sort: 'DATE_ASC',
            limit: 30,
            flowTypes: %w[chat]
          }
        end
      end

      include_context 'for gitlab.com request' do
        let(:variables) do
          {
            namespaceId: namespace_id,
            startDate: start_date,
            endDate: end_date,
            sort: 'DATE_ASC',
            limit: 30,
            flowTypes: %w[chat]
          }
        end
      end
    end
  end

  describe '#get_monthly_waiver' do
    let(:request) { client.get_monthly_waiver }
    let(:query) { described_class::GET_MONTHLY_WAIVER_QUERY }
    let(:monthly_waiver) do
      {
        creditsUsed: 12.25,
        totalCredits: 1000.91,
        dailyUsage: [{ date: '2025-10-01', creditsUsed: 12.25 }]
      }
    end

    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              monthlyWaiver: monthly_waiver
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        monthlyWaiver: monthly_waiver
      }
    end

    include_context 'for self-managed request' do
      let(:variables) { { licenseKey: license_key, startDate: start_date, endDate: end_date } }
    end

    include_context 'for gitlab.com request' do
      let(:variables) { { namespaceId: namespace_id, startDate: start_date, endDate: end_date } }
    end
  end

  describe '#get_monthly_commitment' do
    let(:request) { client.get_monthly_commitment }
    let(:query) { described_class::GET_MONTHLY_COMMITMENT_QUERY }
    let(:monthly_commitment) do
      {
        totalCredits: 1000.91,
        creditsUsed: 250.32,
        dailyUsage: [{ date: '2025-10-01', creditsUsed: 250.32 }]
      }
    end

    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              monthlyCommitment: monthly_commitment
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        monthlyCommitment: monthly_commitment
      }
    end

    include_context 'for self-managed request' do
      let(:variables) { { licenseKey: license_key, startDate: start_date, endDate: end_date } }
    end

    include_context 'for gitlab.com request' do
      let(:variables) { { namespaceId: namespace_id, startDate: start_date, endDate: end_date } }
    end
  end

  describe '#get_overage' do
    let(:request) { client.get_overage }
    let(:query) { described_class::GET_OVERAGE_QUERY }
    let(:overage) do
      {
        isAllowed: true,
        creditsUsed: 250.32,
        dailyUsage: [{ date: '2025-10-01', creditsUsed: 250.32 }]
      }
    end

    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              overage: overage
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        overage: overage
      }
    end

    include_context 'for self-managed request' do
      let(:variables) { { licenseKey: license_key, startDate: start_date, endDate: end_date } }
    end

    include_context 'for gitlab.com request' do
      let(:variables) { { namespaceId: namespace_id, startDate: start_date, endDate: end_date } }
    end
  end

  describe '#get_paid_tier_trial' do
    let(:request) { client.get_paid_tier_trial }
    let(:query) { described_class::GET_PAID_TIER_TRIAL_QUERY }
    let(:paid_tier_trial) do
      {
        isActive: true,
        dailyUsage: [
          { date: '2025-10-01', creditsUsed: 10.5 },
          { date: '2025-10-02', creditsUsed: 15.25 }
        ]
      }
    end

    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              paidTierTrial: paid_tier_trial
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        paidTierTrial: paid_tier_trial
      }
    end

    include_context 'for self-managed request' do
      let(:variables) { { licenseKey: license_key, startDate: start_date, endDate: end_date } }
    end

    include_context 'for gitlab.com request' do
      let(:variables) { { namespaceId: namespace_id, startDate: start_date, endDate: end_date } }
    end
  end

  describe '#get_products' do
    let(:request) { client.get_products }
    let(:query) { described_class::GET_PRODUCTS_QUERY }
    let(:products) do
      [
        {
          id: 'duo_agent_platform',
          title: 'Duo Agent Platform',
          creditsUsed: 150.5,
          flowTypes: [
            { id: 'code_suggestions', title: 'Code Suggestions' },
            { id: 'fix_pipeline', title: 'Fix Pipeline Flow' }
          ]
        },
        {
          id: 'other_product',
          title: 'Other Product',
          creditsUsed: 75.25,
          flowTypes: [
            { id: 'other_flow_type', title: 'Other Flow Type' }
          ]
        }
      ]
    end

    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              products: products
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        products: products
      }
    end

    include_context 'for self-managed request' do
      let(:variables) { { licenseKey: license_key, startDate: start_date, endDate: end_date } }
    end

    include_context 'for gitlab.com request' do
      let(:variables) { { namespaceId: namespace_id, startDate: start_date, endDate: end_date } }
    end
  end

  describe '#get_events_for_user_id' do
    let(:user_id) { 123 }
    let(:args) { { first: 20, last: nil, before: nil, after: nil, flow_types: nil } }
    let(:request) { client.get_events_for_user_id(user_id, args) }
    let(:query) { described_class::GET_USER_EVENTS_QUERY }
    let(:user_events) do
      [
        {
          timestamp: "2025-10-01T16:25:28Z",
          eventType: "ai_token_usage",
          flowType: "Software Development Flow",
          projectId: nil,
          namespaceId: nil,
          creditsUsed: 100.78
        },
        {
          timestamp: "2025-10-01T16:30:12Z",
          eventType: "workflow_execution",
          flowType: "Agentic Chat",
          projectId: "19",
          namespaceId: "99",
          creditsUsed: 200.56
        }
      ]
    end

    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              usersUsage: {
                users: [{
                  events: {
                    nodes: user_events,
                    pageInfo: {
                      hasNextPage: false,
                      hasPreviousPage: false,
                      startCursor: "2025-10-01T16:25:28Z",
                      endCursor: "2025-10-01T16:30:12Z"
                    }
                  }
                }]
              }
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        userEvents: {
          nodes: user_events,
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: "2025-10-01T16:25:28Z",
            endCursor: "2025-10-01T16:30:12Z"
          }
        }
      }
    end

    include_context 'for self-managed request' do
      let(:variables) do
        { licenseKey: license_key, startDate: start_date, endDate: end_date, userIds: [user_id], first: 20 }
      end
    end

    include_context 'for gitlab.com request' do
      let(:variables) do
        { namespaceId: namespace_id, startDate: start_date, endDate: end_date, userIds: [user_id], first: 20 }
      end
    end

    context 'when flow_types are provided' do
      let(:args) { { first: 20, last: nil, before: nil, after: nil, flow_types: %w[code_suggestions agentic_chat] } }

      include_context 'for self-managed request' do
        let(:variables) do
          { licenseKey: license_key, startDate: start_date, endDate: end_date,
            userIds: [user_id], flowTypes: %w[code_suggestions agentic_chat], first: 20 }
        end
      end

      include_context 'for gitlab.com request' do
        let(:variables) do
          { namespaceId: namespace_id, startDate: start_date, endDate: end_date,
            userIds: [user_id], flowTypes: %w[code_suggestions agentic_chat], first: 20 }
        end
      end
    end
  end

  describe '#get_used_flow_types_for_user_id' do
    let(:user_id) { 123 }
    let(:request) { client.get_used_flow_types_for_user_id(user_id) }
    let(:query) { described_class::GET_USED_FLOW_TYPES_QUERY }
    let(:used_flow_types) do
      [
        { id: 'code_suggestions', title: 'Code Suggestions' },
        { id: 'agentic_chat', title: 'Agentic Chat' }
      ]
    end

    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              usersUsage: {
                users: [{
                  usedFlowTypes: used_flow_types
                }]
              }
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        usedFlowTypes: used_flow_types
      }
    end

    include_context 'for self-managed request' do
      let(:variables) { { licenseKey: license_key, startDate: start_date, endDate: end_date, userIds: [user_id] } }
    end

    include_context 'for gitlab.com request' do
      let(:variables) { { namespaceId: namespace_id, startDate: start_date, endDate: end_date, userIds: [user_id] } }
    end

    context 'when no users are returned' do
      let(:portal_response) do
        {
          success: true,
          data: {
            subscription: {
              gitlabCreditsUsage: {
                usersUsage: {
                  users: []
                }
              }
            }
          }
        }
      end

      let(:expected_response) do
        {
          success: true,
          usedFlowTypes: nil
        }
      end

      include_context 'for self-managed request' do
        let(:variables) do
          { licenseKey: license_key, startDate: start_date, endDate: end_date, userIds: [user_id] }
        end
      end

      include_context 'for gitlab.com request' do
        let(:variables) do
          { namespaceId: namespace_id, startDate: start_date, endDate: end_date, userIds: [user_id] }
        end
      end
    end
  end

  describe '#get_blocked_statuses' do
    let(:entity_ids) { %w[123 321] }
    let(:request) { client.get_blocked_statuses(entity_ids) }
    let(:query) { described_class::GET_BLOCKED_STATUSES_QUERY }
    let(:blocked_statuses) do
      [
        {
          entityId: '123',
          blocked: true,
          capType: 'FLAT_USER_CAP'
        },
        {
          entityId: '321',
          blocked: false,
          capType: nil
        }
      ]
    end

    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              blockedStatuses: { nodes: blocked_statuses }
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        blockedStatuses: blocked_statuses
      }
    end

    include_context 'for self-managed request' do
      let(:variables) { { licenseKey: license_key, startDate: start_date, endDate: end_date, entityIds: entity_ids } }
    end

    include_context 'for gitlab.com request' do
      let(:variables) { { namespaceId: namespace_id, startDate: start_date, endDate: end_date, entityIds: entity_ids } }
    end
  end

  describe '#get_usage_for_user_ids' do
    let(:user_ids) { [123, 321] }
    let(:request) { client.get_usage_for_user_ids(user_ids) }
    let(:query) { described_class::GET_USERS_USAGE_QUERY }
    let(:users_usage) do
      [
        {
          userId: 123,
          totalCredits: 100.12,
          creditsUsed: 500.23,
          monthlyCommitmentCreditsUsed: 400.45,
          monthlyWaiverCreditsUsed: 25.56,
          overageCreditsUsed: 50.67,
          paidTierTrialCreditsUsed: 10.0,
          totalCreditsUsed: 986.91
        },
        {
          userId: 321,
          totalCredits: 100.12,
          creditsUsed: 50.23,
          monthlyCommitmentCreditsUsed: 0,
          monthlyWaiverCreditsUsed: 12.34,
          overageCreditsUsed: 0,
          paidTierTrialCreditsUsed: 0,
          totalCreditsUsed: 62.57
        }
      ]
    end

    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              usersUsage: { users: users_usage }
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        usersUsage: users_usage
      }
    end

    include_context 'for self-managed request' do
      let(:variables) do
        { licenseKey: license_key, startDate: start_date, endDate: end_date, userIds: user_ids, flowTypes: nil }
      end
    end

    include_context 'for gitlab.com request' do
      let(:variables) do
        { namespaceId: namespace_id, startDate: start_date, endDate: end_date, userIds: user_ids, flowTypes: nil }
      end
    end

    context 'when flow_types are provided' do
      let(:request) { client.get_usage_for_user_ids(user_ids, flow_types: %w[chat]) }

      include_context 'for self-managed request' do
        let(:variables) do
          {
            licenseKey: license_key,
            startDate: start_date,
            endDate: end_date,
            userIds: user_ids,
            flowTypes: %w[chat]
          }
        end
      end

      include_context 'for gitlab.com request' do
        let(:variables) do
          {
            namespaceId: namespace_id,
            startDate: start_date,
            endDate: end_date,
            userIds: user_ids,
            flowTypes: %w[chat]
          }
        end
      end
    end
  end

  describe '#get_consumers' do
    let(:args) { { sort: :total_credits_used_desc, first: 10, last: nil, before: nil, after: nil } }
    let(:request) { client.get_consumers(args) }
    let(:query) { described_class::GET_CONSUMERS_QUERY }
    let(:consumers) do
      {
        nodes: [
          {
            userId: 123,
            totalCredits: 100.12,
            creditsUsed: 500.23,
            monthlyCommitmentCreditsUsed: 400.45,
            monthlyWaiverCreditsUsed: 25.56,
            overageCreditsUsed: 50.67,
            paidTierTrialCreditsUsed: 10.0,
            totalCreditsUsed: 986.91,
            entityType: 'USER'
          },
          {
            userId: 321,
            totalCredits: 100.12,
            creditsUsed: 50.23,
            monthlyCommitmentCreditsUsed: 0,
            monthlyWaiverCreditsUsed: 12.34,
            overageCreditsUsed: 0,
            paidTierTrialCreditsUsed: 0,
            totalCreditsUsed: 62.57,
            entityType: 'NON_HUMAN'
          }
        ],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: "cursor1",
          endCursor: "cursor2"
        }
      }
    end

    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              usersUsage: { consumers: consumers }
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        consumers: consumers
      }
    end

    include_context 'for self-managed request' do
      let(:variables) do
        { licenseKey: license_key, startDate: start_date, endDate: end_date,
          sort: 'TOTAL_CREDITS_USED_DESC', first: 10, last: nil, before: nil, after: nil, flowTypes: nil }
      end
    end

    include_context 'for gitlab.com request' do
      let(:variables) do
        { namespaceId: namespace_id, startDate: start_date, endDate: end_date,
          sort: 'TOTAL_CREDITS_USED_DESC', first: 10, last: nil, before: nil, after: nil, flowTypes: nil }
      end
    end

    context 'when flow_types are provided' do
      let(:args) do
        { sort: :total_credits_used_desc, first: 10, last: nil, before: nil, after: nil, flow_types: %w[chat] }
      end

      include_context 'for self-managed request' do
        let(:variables) do
          { licenseKey: license_key, startDate: start_date, endDate: end_date,
            sort: 'TOTAL_CREDITS_USED_DESC', first: 10, last: nil, before: nil, after: nil, flowTypes: %w[chat] }
        end
      end

      include_context 'for gitlab.com request' do
        let(:variables) do
          { namespaceId: namespace_id, startDate: start_date, endDate: end_date,
            sort: 'TOTAL_CREDITS_USED_DESC', first: 10, last: nil, before: nil, after: nil, flowTypes: %w[chat] }
        end
      end
    end

    it 'requests entity type from CustomerDot' do
      expect(query).to include('entityType')
    end

    context 'when CustomerDot does not support entityType' do
      let(:fallback_query) { described_class::GET_CONSUMERS_WITHOUT_ENTITY_TYPE_QUERY }
      let(:fallback_params) { params.merge(query: fallback_query) }
      let(:undefined_field_response) do
        {
          errors: [{ message: "Field 'entityType' doesn't exist on type 'GitlabCreditsConsumer'" }]
        }
      end

      it 'retries without entityType' do
        expect(::Gitlab::HTTP).to receive(:post).with(
          graphql_url,
          headers: headers,
          body: params.to_json
        ).and_return(instance_double(
          HTTParty::Response,
          response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
          parsed_response: undefined_field_response
        ))

        expect(::Gitlab::HTTP).to receive(:post).with(
          graphql_url,
          headers: headers,
          body: fallback_params.to_json
        ).and_return(instance_double(
          HTTParty::Response,
          response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
          parsed_response: portal_response
        ))

        expect(request).to eq(expected_response)
      end
    end

    context 'when sort is nil' do
      let(:args) { { sort: nil, first: 10, last: nil, before: nil, after: nil } }

      include_context 'for self-managed request' do
        let(:variables) do
          { licenseKey: license_key, startDate: start_date, endDate: end_date,
            sort: nil, first: 10, last: nil, before: nil, after: nil, flowTypes: nil }
        end
      end
    end
  end

  describe '#get_users_usage_stats' do
    let(:request) { client.get_users_usage_stats }
    let(:query) { described_class::GET_USERS_USAGE_STATS_QUERY }
    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              usersUsage: {
                totalActiveUsers: 5,
                totalUsersUsingCredits: 9.87,
                totalUsersUsingMonthlyCommitment: 8.76,
                totalUsersUsingOverage: 6.54,
                creditsUsed: 123.45,
                dailyUsage: [{ date: '2025-10-01', creditsUsed: 123.45 }]
              }
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        usersUsage: portal_response[:data][:subscription][:gitlabCreditsUsage][:usersUsage]
      }
    end

    include_context 'for self-managed request' do
      let(:variables) { { licenseKey: license_key, startDate: start_date, endDate: end_date } }
    end

    include_context 'for gitlab.com request' do
      let(:variables) { { namespaceId: namespace_id, startDate: start_date, endDate: end_date } }
    end

    context 'when flow_types are provided' do
      let(:request) { client.get_users_usage_stats(flow_types: %w[chat]) }

      include_context 'for self-managed request' do
        let(:variables) do
          {
            licenseKey: license_key,
            startDate: start_date,
            endDate: end_date,
            flowTypes: %w[chat]
          }
        end
      end

      include_context 'for gitlab.com request' do
        let(:variables) do
          {
            namespaceId: namespace_id,
            startDate: start_date,
            endDate: end_date,
            flowTypes: %w[chat]
          }
        end
      end
    end
  end

  describe '#get_trial_usage' do
    let(:request) { client.get_trial_usage }
    let(:query) { described_class::GET_TRIAL_USAGE_QUERY }
    let(:trial_usage) do
      {
        activeTrial: {
          startDate: "2026-02-01",
          endDate: "2026-03-03"
        },
        usersUsage: {
          creditsUsed: 12.5,
          totalUsersUsingCredits: 3,
          users: []
        }
      }
    end

    let(:portal_response) do
      {
        success: true,
        data: {
          trialUsage: trial_usage
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        trialUsage: trial_usage
      }
    end

    include_context 'for self-managed request' do
      let(:variables) { { licenseKey: license_key, startDate: start_date, endDate: end_date } }
    end

    include_context 'for gitlab.com request' do
      let(:variables) { { namespaceId: namespace_id, startDate: start_date, endDate: end_date } }
    end

    context 'when trial has zero usage' do
      let(:trial_usage) do
        {
          activeTrial: {
            startDate: "2026-01-06",
            endDate: "2026-04-06"
          },
          usersUsage: {
            creditsUsed: 0.0,
            totalUsersUsingCredits: 0,
            users: []
          }
        }
      end

      let(:portal_response) do
        {
          success: true,
          data: {
            trialUsage: trial_usage
          }
        }
      end

      let(:expected_response) do
        {
          success: true,
          trialUsage: trial_usage
        }
      end

      include_context 'for self-managed request' do
        let(:variables) { { licenseKey: license_key, startDate: start_date, endDate: end_date } }
      end

      include_context 'for gitlab.com request' do
        let(:variables) { { namespaceId: namespace_id, startDate: start_date, endDate: end_date } }
      end
    end
  end

  describe '#get_trial_usage_for_user_ids' do
    let(:user_ids) { [123, 456] }
    let(:request) { client.get_trial_usage_for_user_ids(user_ids) }
    let(:query) { described_class::GET_TRIAL_USAGE_FOR_USER_IDS_QUERY }
    let(:trial_users_usage) do
      [
        {
          userId: 123,
          totalCredits: 24.0,
          creditsUsed: 4.5
        },
        {
          userId: 456,
          totalCredits: 24.0,
          creditsUsed: nil
        }
      ]
    end

    let(:portal_response) do
      {
        success: true,
        data: {
          trialUsage: {
            activeTrial: {
              startDate: "2026-01-06",
              endDate: "2026-04-06"
            },
            usersUsage: {
              creditsUsed: 4.5,
              totalUsersUsingCredits: 1,
              users: trial_users_usage
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        usersUsage: trial_users_usage
      }
    end

    include_context 'for self-managed request' do
      let(:variables) { { licenseKey: license_key, startDate: start_date, endDate: end_date, userIds: user_ids } }
    end

    include_context 'for gitlab.com request' do
      let(:variables) { { namespaceId: namespace_id, startDate: start_date, endDate: end_date, userIds: user_ids } }
    end

    context 'when all users have null creditsUsed' do
      let(:user_ids) { [123, 456, 789] }
      let(:trial_users_usage) do
        [
          {
            userId: 123,
            totalCredits: 24.0,
            creditsUsed: nil
          },
          {
            userId: 456,
            totalCredits: 24.0,
            creditsUsed: nil
          },
          {
            userId: 789,
            totalCredits: 24.0,
            creditsUsed: nil
          }
        ]
      end

      let(:portal_response) do
        {
          success: true,
          data: {
            trialUsage: {
              activeTrial: {
                startDate: "2026-01-06",
                endDate: "2026-04-06"
              },
              usersUsage: {
                creditsUsed: 0.0,
                totalUsersUsingCredits: 0,
                users: trial_users_usage
              }
            }
          }
        }
      end

      let(:expected_response) do
        {
          success: true,
          usersUsage: trial_users_usage
        }
      end

      include_context 'for self-managed request' do
        let(:variables) do
          { licenseKey: license_key, startDate: start_date, endDate: end_date, userIds: user_ids }
        end
      end

      include_context 'for gitlab.com request' do
        let(:variables) do
          { namespaceId: namespace_id, startDate: start_date, endDate: end_date, userIds: user_ids }
        end
      end
    end
  end

  describe '#get_budget_caps' do
    let(:request) { client.get_budget_caps }
    let(:query) { described_class::GET_BUDGET_CAPS_QUERY }
    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            budgetControls: {
              subscription: {
                subscriptionName: "A-S00012345",
                subscriptionCap: 500.0,
                subscriptionCapEnabled: true,
                flatUserCap: 100.0,
                flatUserCapEnabled: true
              },
              userBudgetCapOverrides: {
                nodes: [
                  {
                    entityId: "1",
                    cap: 50.0,
                    capEnabled: true,
                    selfManagedInstanceActivationId: nil,
                    createdAt: "2026-04-01T00:00:00Z",
                    updatedAt: "2026-04-01T00:00:00Z"
                  }
                ],
                pageInfo: {
                  hasNextPage: false,
                  hasPreviousPage: false,
                  startCursor: nil,
                  endCursor: nil
                }
              }
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        budgetControls: portal_response.dig(
          :data, :subscription, :budgetControls
        )
      }
    end

    include_context 'for self-managed request' do
      let(:variables) { { licenseKey: license_key } }
    end

    include_context 'for gitlab.com request' do
      let(:variables) { { namespaceId: namespace_id } }
    end

    context 'with entity_ids filter' do
      let(:request) { client.get_budget_caps(entity_ids: %w[1 2]) }

      context 'for gitlab.com request' do
        let(:namespace_id) { 1234 }
        let(:license_key) { nil }
        let(:admin_headers) do
          {
            "X-Admin-Email" => "gl_com_api@gitlab.com",
            "X-Admin-Token" => "customer_admin_token"
          }
        end

        it 'passes entity_ids with namespaceId' do
          expect(::Gitlab::HTTP).to receive(:post).with(
            graphql_url,
            headers: headers,
            body: {
              query: query,
              variables: {
                instanceId: Gitlab::GlobalAnonymousId.instance_id,
                namespaceId: namespace_id,
                entityIds: %w[1 2]
              }
            }.to_json
          ).and_return(instance_double(
            HTTParty::Response,
            response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
            parsed_response: portal_response
          ))

          expect(request).to eq(expected_response)
        end
      end

      context 'for self-managed request' do
        let(:admin_headers) { nil }
        let(:namespace_id) { nil }
        let(:license_key) { 'license_key' }

        it 'passes entity_ids with licenseKey' do
          expect(::Gitlab::HTTP).to receive(:post).with(
            graphql_url,
            headers: headers,
            body: {
              query: query,
              variables: {
                instanceId: Gitlab::GlobalAnonymousId.instance_id,
                licenseKey: license_key,
                entityIds: %w[1 2]
              }
            }.to_json
          ).and_return(instance_double(
            HTTParty::Response,
            response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
            parsed_response: portal_response
          ))

          expect(request).to eq(expected_response)
        end
      end
    end

    context 'with pagination args' do
      let(:request) do
        client.get_budget_caps(args: { first: 10, after: "cursor123" })
      end

      context 'for gitlab.com request' do
        let(:namespace_id) { 1234 }
        let(:license_key) { nil }
        let(:admin_headers) do
          {
            "X-Admin-Email" => "gl_com_api@gitlab.com",
            "X-Admin-Token" => "customer_admin_token"
          }
        end

        it 'passes pagination variables with namespaceId' do
          expect(::Gitlab::HTTP).to receive(:post).with(
            graphql_url,
            headers: headers,
            body: {
              query: query,
              variables: {
                instanceId: Gitlab::GlobalAnonymousId.instance_id,
                namespaceId: namespace_id,
                first: 10,
                after: "cursor123"
              }
            }.to_json
          ).and_return(instance_double(
            HTTParty::Response,
            response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
            parsed_response: portal_response
          ))

          expect(request).to eq(expected_response)
        end
      end

      context 'for self-managed request' do
        let(:admin_headers) { nil }
        let(:namespace_id) { nil }
        let(:license_key) { 'license_key' }

        it 'passes pagination variables with licenseKey' do
          expect(::Gitlab::HTTP).to receive(:post).with(
            graphql_url,
            headers: headers,
            body: {
              query: query,
              variables: {
                instanceId: Gitlab::GlobalAnonymousId.instance_id,
                licenseKey: license_key,
                first: 10,
                after: "cursor123"
              }
            }.to_json
          ).and_return(instance_double(
            HTTParty::Response,
            response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
            parsed_response: portal_response
          ))

          expect(request).to eq(expected_response)
        end
      end
    end
  end

  describe '#upsert_user_budget_cap_overrides' do
    let(:overrides) do
      [
        { entityId: "1", capAmount: 100.0, enabled: true },
        { entityId: "2", capAmount: 200.0, enabled: false }
      ]
    end

    let(:request) do
      client.upsert_user_budget_cap_overrides(overrides: overrides)
    end

    let(:query) do
      described_class::UPSERT_USER_BUDGET_CAPS_MUTATION
    end

    context 'for gitlab.com request' do
      let(:namespace_id) { 1234 }
      let(:license_key) { nil }
      let(:admin_headers) do
        {
          "X-Admin-Email" => "gl_com_api@gitlab.com",
          "X-Admin-Token" => "customer_admin_token"
        }
      end

      let(:expected_variables) do
        {
          input: {
            overrides: overrides,
            namespaceId: namespace_id
          }
        }
      end

      let(:portal_response) do
        {
          data: {
            upsertUserBudgetCapsBulk: {
              userBudgetCapOverrides: [
                {
                  entityId: "1",
                  cap: 100.0,
                  capEnabled: true,
                  selfManagedInstanceActivationId: nil
                },
                {
                  entityId: "2",
                  cap: 200.0,
                  capEnabled: false,
                  selfManagedInstanceActivationId: nil
                }
              ],
              errors: []
            }
          }
        }
      end

      it 'sends correct params and returns success' do
        expect(::Gitlab::HTTP).to receive(:post).with(
          graphql_url,
          headers: headers,
          body: {
            query: query, variables: expected_variables
          }.to_json
        ).and_return(instance_double(
          HTTParty::Response,
          response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
          parsed_response: portal_response
        ))

        expect(request).to eq({
          success: true,
          userBudgetCapOverrides:
            portal_response.dig(
              :data, :upsertUserBudgetCapsBulk,
              :userBudgetCapOverrides
            )
        })
      end

      context 'when CDot returns errors' do
        let(:portal_response) do
          {
            data: {
              upsertUserBudgetCapsBulk: {
                userBudgetCapOverrides: nil,
                errors: ["Cap must be greater than or equal to 0"]
              }
            }
          }
        end

        it 'returns failure with errors' do
          expect(::Gitlab::HTTP).to receive(:post).with(
            graphql_url,
            headers: headers,
            body: {
              query: query, variables: expected_variables
            }.to_json
          ).and_return(instance_double(
            HTTParty::Response,
            response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
            parsed_response: portal_response
          ))

          expect(request).to eq({
            success: false,
            errors: ["Cap must be greater than or equal to 0"]
          })
        end
      end

      context 'when CDot returns nil mutation data' do
        let(:portal_response) do
          { data: { upsertUserBudgetCapsBulk: nil } }
        end

        it 'raises an error' do
          expect(::Gitlab::HTTP).to receive(:post).with(
            graphql_url,
            headers: headers,
            body: {
              query: query, variables: expected_variables
            }.to_json
          ).and_return(instance_double(
            HTTParty::Response,
            response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
            parsed_response: portal_response
          ))

          expect { request }.to raise_error(
            described_class::ResponseError
          )
        end
      end
    end

    context 'for self-managed request' do
      let(:admin_headers) { nil }
      let(:namespace_id) { nil }
      let(:license_key) { 'license_key' }

      let(:expected_variables) do
        {
          input: {
            overrides: overrides,
            licenseKey: license_key,
            uniqueInstanceId: Gitlab::GlobalAnonymousId.instance_id
          }
        }
      end

      let(:portal_response) do
        {
          data: {
            upsertUserBudgetCapsBulk: {
              userBudgetCapOverrides: [
                {
                  entityId: "1",
                  cap: 100.0,
                  capEnabled: true,
                  selfManagedInstanceActivationId: "activation-123"
                }
              ],
              errors: []
            }
          }
        }
      end

      it 'sends license_key and uniqueInstanceId' do
        expect(::Gitlab::HTTP).to receive(:post).with(
          graphql_url,
          headers: headers,
          body: {
            query: query, variables: expected_variables
          }.to_json
        ).and_return(instance_double(
          HTTParty::Response,
          response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
          parsed_response: portal_response
        ))

        expect(request).to eq({
          success: true,
          userBudgetCapOverrides:
            portal_response.dig(
              :data, :upsertUserBudgetCapsBulk,
              :userBudgetCapOverrides
            )
        })
      end
    end
  end

  describe '#upsert_flat_user_cap' do
    let(:flat_user_cap) { 50.0 }
    let(:flat_user_cap_enabled) { true }
    let(:request) do
      client.upsert_flat_user_cap(
        flat_user_cap: flat_user_cap,
        flat_user_cap_enabled: flat_user_cap_enabled
      )
    end

    let(:query) { described_class::UPSERT_FLAT_USER_CAP_MUTATION }

    context 'for gitlab.com request' do
      let(:namespace_id) { 1234 }
      let(:license_key) { nil }
      let(:admin_headers) do
        {
          "X-Admin-Email" => "gl_com_api@gitlab.com",
          "X-Admin-Token" => "customer_admin_token"
        }
      end

      let(:expected_variables) do
        {
          input: {
            flatUserCap: flat_user_cap,
            flatUserCapEnabled: flat_user_cap_enabled,
            namespaceId: namespace_id
          }
        }
      end

      let(:portal_response) do
        {
          data: {
            upsertBudgetCapSubscription: {
              subscriptionBudgetCap: {
                subscriptionName: "A-S00012345",
                flatUserCap: flat_user_cap,
                flatUserCapEnabled: flat_user_cap_enabled
              },
              errors: []
            }
          }
        }
      end

      it 'sends correct params and returns success' do
        expect(::Gitlab::HTTP).to receive(:post).with(
          graphql_url,
          headers: headers,
          body: { query: query, variables: expected_variables }.to_json
        ).and_return(instance_double(
          HTTParty::Response,
          response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
          parsed_response: portal_response
        ))

        expect(request).to eq({
          success: true,
          subscriptionBudgetCap:
            portal_response.dig(
              :data, :upsertBudgetCapSubscription,
              :subscriptionBudgetCap
            )
        })
      end

      context 'when CDot returns errors' do
        let(:portal_response) do
          {
            data: {
              upsertBudgetCapSubscription: {
                subscriptionBudgetCap: nil,
                errors: ["Flat user cap must be greater than or equal to 0"]
              }
            }
          }
        end

        it 'returns failure with errors' do
          expect(::Gitlab::HTTP).to receive(:post).with(
            graphql_url,
            headers: headers,
            body: { query: query, variables: expected_variables }.to_json
          ).and_return(instance_double(
            HTTParty::Response,
            response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
            parsed_response: portal_response
          ))

          expect(request).to eq({
            success: false,
            errors: ["Flat user cap must be greater than or equal to 0"]
          })
        end
      end

      context 'when CDot returns nil mutation data' do
        let(:portal_response) do
          { data: { upsertBudgetCapSubscription: nil } }
        end

        it 'raises an error' do
          expect(::Gitlab::HTTP).to receive(:post).with(
            graphql_url,
            headers: headers,
            body: { query: query, variables: expected_variables }.to_json
          ).and_return(instance_double(
            HTTParty::Response,
            response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
            parsed_response: portal_response
          ))

          expect { request }.to raise_error(
            described_class::ResponseError
          )
        end
      end

      context 'when CDot returns an unsuccessful response' do
        let(:portal_response) do
          {
            data: {
              errors: "Something went wrong"
            }
          }
        end

        it 'raises an error' do
          expect(::Gitlab::HTTP).to receive(:post).with(
            graphql_url,
            headers: headers,
            body: { query: query, variables: expected_variables }.to_json
          ).and_return(instance_double(
            HTTParty::Response,
            response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
            parsed_response: portal_response
          ))

          expect { request }.to raise_error(
            described_class::ResponseError,
            "Received an error from CustomerDot"
          )
        end
      end
    end

    context 'for self-managed request' do
      let(:admin_headers) { nil }
      let(:namespace_id) { nil }
      let(:license_key) { 'license_key' }

      let(:expected_variables) do
        {
          input: {
            flatUserCap: flat_user_cap,
            flatUserCapEnabled: flat_user_cap_enabled,
            licenseKey: license_key
          }
        }
      end

      let(:portal_response) do
        {
          data: {
            upsertBudgetCapSubscription: {
              subscriptionBudgetCap: {
                subscriptionName: "A-S00012345",
                flatUserCap: flat_user_cap,
                flatUserCapEnabled: flat_user_cap_enabled
              },
              errors: []
            }
          }
        }
      end

      it 'sends license_key without namespaceId' do
        expect(::Gitlab::HTTP).to receive(:post).with(
          graphql_url,
          headers: headers,
          body: { query: query, variables: expected_variables }.to_json
        ).and_return(instance_double(
          HTTParty::Response,
          response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
          parsed_response: portal_response
        ))

        expect(request).to eq({
          success: true,
          subscriptionBudgetCap:
            portal_response.dig(
              :data, :upsertBudgetCapSubscription,
              :subscriptionBudgetCap
            )
        })
      end
    end
  end
end
