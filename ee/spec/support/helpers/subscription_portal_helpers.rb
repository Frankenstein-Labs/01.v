# frozen_string_literal: true

module SubscriptionPortalHelpers
  include StubRequests

  def graphql_url
    ::Gitlab::Routing.url_helpers.subscription_portal_graphql_url
  end

  def stub_signing_key
    key = OpenSSL::PKey::RSA.new(2048)

    stub_application_setting(customers_dot_jwt_signing_key: key)
  end

  def billing_plans_data
    Gitlab::Json.parse(plans_fixture.read).map do |data|
      data.deep_symbolize_keys
    end
  end

  def stub_cdot_namespace_eligible_trials
    allow(Gitlab::SubscriptionPortal::Client).to receive(:namespace_eligible_trials) do |params|
      namespaces_response = params[:namespace_ids].to_h { |id| [id.to_s, GitlabSubscriptions::Trials::TRIAL_TYPES] }

      { success: true, data: { namespaces: namespaces_response } }
    end
  end

  def stub_billing_plans(namespace_id, plan = 'free', plans_data = nil, raise_error: nil)
    gitlab_plans_url = ::Gitlab::Routing.url_helpers.subscription_portal_gitlab_plans_url

    stub = stub_full_request("#{gitlab_plans_url}?namespace_id=#{namespace_id}&plan=#{plan}")
             .with(headers: { 'Accept' => 'application/json' })

    if raise_error
      stub.to_raise(raise_error)
    else
      stub.to_return(status: 200, body: plans_data || plans_fixture)
    end
  end

  def stub_subscription_request_seat_usage(eligible)
    stub_full_request(graphql_url, method: :post)
      .with(body: /isEligibleForSeatUsageAlerts/)
    .to_return(status: 200, body: {
      data: {
        subscription: {
          isEligibleForSeatUsageAlerts: eligible
        }
      }
    }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_subscription_monthly_commitment_request(total_credits: 0)
    stub_full_request(graphql_url, method: :post)
      .with(body: /subscriptionUsageMonthlyCommitment/)
      .to_return(status: 200, body: {
        data: {
          subscription: {
            gitlabCreditsUsage: {
              monthlyCommitment: {
                totalCredits: total_credits,
                creditsUsed: 0,
                dailyUsage: []
              }
            }
          }
        }
      }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_reconciliation_request(eligible)
    stub_full_request(graphql_url, method: :post)
      .with(body: /eligibleForSeatReconciliation/)
    .to_return(status: 200, body: {
      data: {
        reconciliation: {
          eligibleForSeatReconciliation: eligible
        }
      }
    }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_subscription_management_data(namespace_id, can_add_seats: true, can_renew: true, next_term_start_date: nil)
    stub_full_request(graphql_url, method: :post)
      .with(
        body: "{\"operationName\":\"getSubscriptionData\",\"variables\":{\"namespaceId\":#{namespace_id}},\"query\":\"query getSubscriptionData($namespaceId: ID!) {\\n  subscription(namespaceId: $namespaceId) {\\n    canAddSeats\\n    canRenew\\n    nextTermStartDate\\n    __typename\\n  }\\n}\"}"
      )
      .to_return(status: 200, body: {
        data: {
          subscription: {
            canAddSeats: can_add_seats,
            canRenew: can_renew,
            nextTermStartDate: next_term_start_date
          }
        }
      }.to_json)
  end

  def stub_subscription_permissions_data(namespace_id, can_add_seats: true, can_add_duo_pro_seats: true, can_renew: true, community_plan: false, reason: 'MANAGED_BY_RESELLER')
    stub_full_request(graphql_url, method: :post)
      .with(
        body: "{\"operationName\":\"getSubscriptionPermissionsData\",\"variables\":{\"namespaceId\":#{namespace_id}},\"query\":\"query getSubscriptionPermissionsData($namespaceId: ID, $subscriptionName: String) {\\n  subscription(namespaceId: $namespaceId, subscriptionName: $subscriptionName) {\\n    canAddSeats\\n    canAddDuoProSeats\\n    canRenew\\n    communityPlan\\n    __typename\\n  }\\n  userActionAccess(namespaceId: $namespaceId, subscriptionName: $subscriptionName) {\\n    limitedAccessReason\\n    __typename\\n  }\\n}\"}"
      )
      .to_return(status: 200, body: {
        data: {
          subscription: {
            canAddSeats: can_add_seats,
            canAddDuoProSeats: can_add_duo_pro_seats,
            canRenew: can_renew,
            communityPlan: community_plan
          },
          userActionAccess: {
            limitedAccessReason: reason
          }
        }
      }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_temporary_extension_data(namespace_id)
    stub_full_request(graphql_url, method: :post)
      .with(
        body: "{\"operationName\":\"getTemporaryExtensionData\",\"variables\":{\"namespaceId\":#{namespace_id}},\"query\":\"query getTemporaryExtensionData($namespaceId: ID!) {\\n  temporaryExtension(namespaceId: $namespaceId) {\\n    endDate\\n    __typename\\n  }\\n}\"}"
      )
      .to_return(status: 200, body: {
        data: {
          temporaryExtension: {
            endDate: (Date.current + 2.weeks).strftime('%F')
          }
        }
      }.to_json)
  end

  # Stubs the subscription portal client to prevent real HTTP calls in tests
  # This is needed because TrialDurationService makes HTTP requests to fetch trial types
  #
  # @param trial_types [Hash] Custom trial types to return. Defaults to standard trial types.
  # @param success [Boolean] Whether the API call should be successful. Defaults to true.
  #
  # @example Basic usage
  #   stub_subscription_trial_types
  #
  # @example Custom trial types
  #   stub_subscription_trial_types(
  #     trial_types: {
  #       'free' => { duration_days: 14 },
  #       'premium' => { duration_days: 60 }
  #     }
  #   )
  #
  # @example Simulate API failure
  #   stub_subscription_trial_types(success: false)
  def stub_subscription_trial_types(trial_types: nil, success: true)
    default_trial_types = {
      GitlabSubscriptions::Trials::FREE_TRIAL_TYPE => { duration_days: 30 },
      GitlabSubscriptions::Trials::DUO_ENTERPRISE_TRIAL_TYPE => { duration_days: 60 }
    }

    response = if success
                 {
                   success: true,
                   data: {
                     trial_types: trial_types || default_trial_types
                   }
                 }
               else
                 {
                   success: false,
                   data: {
                     errors: ['API Error']
                   }
                 }
               end

    allow(Gitlab::SubscriptionPortal::Client).to receive(:namespace_trial_types).and_return(response)
  end

  private

  def plans_fixture
    File.new(Rails.root.join('ee/spec/fixtures/gitlab_com_plans.json'))
  end
end
