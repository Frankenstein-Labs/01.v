# frozen_string_literal: true

module Gitlab
  module SubscriptionPortal
    class SubscriptionUsageClient < Client
      include ::Gitlab::Utils::StrongMemoize

      ResponseError = Class.new(StandardError)

      GET_METADATA_QUERY = <<~GQL
        query subscriptionUsageMetadata(
          $instanceId: String,
          $namespaceId: ID,
          $licenseKey: String,
          $gitlabVersion: String!,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date,
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(instanceId: $instanceId, startDate: $startDate, endDate: $endDate) {
              startDate
              endDate
              enabled
              isOutdatedClient(gitlabVersion: $gitlabVersion)
              lastEventTransactionAt
              overageTermsAccepted
              canAcceptOverageTerms
              dapPromoEnabled
              usageDashboardPath
            }
          }
        }
      GQL

      GET_PAID_TIER_TRIAL_QUERY = <<~GQL
        query subscriptionUsagePaidTierTrial(
          $instanceId: String,
          $namespaceId: ID,
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(instanceId: $instanceId, startDate: $startDate, endDate: $endDate) {
              paidTierTrial {
                isActive
                dailyUsage {
                  date
                  creditsUsed
                }
              }
            }
          }
        }
      GQL

      GET_SUBSCRIPTION_USAGE_QUERY = <<~GQL
        query subscriptionUsage(
          $instanceId: String,
          $namespaceId: ID,
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date,
          $sort: DailyUsageSort,
          $limit: Int,
          $flowTypes: [String!]
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(instanceId: $instanceId, startDate: $startDate, endDate: $endDate, flowTypes: $flowTypes) {
              creditsUsed
              dailyAverage
              dailyUsage(sort: $sort, limit: $limit) {
                date
                creditsUsed
              }
            }
          }
        }
      GQL

      GET_MONTHLY_WAIVER_QUERY = <<~GQL
        query subscriptionUsageMonthlyWaiver(
          $instanceId: String,
          $namespaceId: ID,
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(instanceId: $instanceId, startDate: $startDate, endDate: $endDate) {
              monthlyWaiver {
                creditsUsed
                totalCredits
                dailyUsage {
                  date
                  creditsUsed
                }
              }
            }
          }
        }
      GQL

      GET_MONTHLY_COMMITMENT_QUERY = <<~GQL
        query subscriptionUsageMonthlyCommitment(
          $instanceId: String,
          $namespaceId: ID,
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(instanceId: $instanceId, startDate: $startDate, endDate: $endDate) {
              monthlyCommitment {
                totalCredits
                creditsUsed
                dailyUsage {
                  date
                  creditsUsed
                }
              }
            }
          }
        }
      GQL

      GET_OVERAGE_QUERY = <<~GQL
        query subscriptionUsageOverage(
          $instanceId: String,
          $namespaceId: ID,
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(instanceId: $instanceId, startDate: $startDate, endDate: $endDate) {
              overage {
                isAllowed
                creditsUsed
                dailyUsage {
                  date
                  creditsUsed
                }
              }
            }
          }
        }
      GQL

      GET_USER_EVENTS_QUERY = <<~GQL
        query subscriptionUsageUserEvents(
          $instanceId: String,
          $namespaceId: ID,
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date,
          $userIds: [Int!]!,
          $flowTypes: [String],
          $first: Int,
          $last: Int,
          $after: String,
          $before: String
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(instanceId: $instanceId, startDate: $startDate, endDate: $endDate) {
              usersUsage {
                users(userIds: $userIds) {
                  events(first: $first, last: $last, before: $before, after: $after, flowTypes: $flowTypes) {
                    nodes {
                      timestamp
                      eventType
                      flowType
                      projectId
                      namespaceId
                      creditsUsed
                      sessionId
                      showSessionLink
                    }
                    pageInfo {
                      hasNextPage
                      hasPreviousPage
                      startCursor
                      endCursor
                    }
                  }
                }
              }
            }
          }
        }
      GQL

      GET_USED_FLOW_TYPES_QUERY = <<~GQL
        query subscriptionUsageUsedFlowTypes(
          $instanceId: String,
          $namespaceId: ID,
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date,
          $userIds: [Int!]!
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(instanceId: $instanceId, startDate: $startDate, endDate: $endDate) {
              usersUsage {
                users(userIds: $userIds) {
                  usedFlowTypes {
                    id
                    title
                  }
                }
              }
            }
          }
        }
      GQL

      GET_USERS_USAGE_QUERY = <<~GQL
        query subscriptionUsageForUserIds(
          $instanceId: String,
          $namespaceId: ID,
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date,
          $userIds: [Int!]!,
          $flowTypes: [String!]
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(instanceId: $instanceId, startDate: $startDate, endDate: $endDate, flowTypes: $flowTypes) {
              usersUsage {
                users(userIds: $userIds) {
                  userId
                  totalCredits
                  creditsUsed
                  totalCreditsUsed
                  monthlyCommitmentCreditsUsed
                  monthlyWaiverCreditsUsed
                  overageCreditsUsed
                  paidTierTrialCreditsUsed
                }
              }
            }
          }
        }
      GQL

      GET_CONSUMERS_QUERY = <<~GQL
        query subscriptionUsageForConsumers(
          $instanceId: String,
          $namespaceId: ID,
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date,
          $sort: GitlabCreditsConsumerSort,
          $first: Int,
          $last: Int,
          $after: String,
          $before: String,
          $flowTypes: [String!]
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(instanceId: $instanceId, startDate: $startDate, endDate: $endDate, flowTypes: $flowTypes) {
              usersUsage {
                consumers(
                  sort: $sort
                  first: $first
                  last: $last
                  after: $after
                  before: $before
                ) {
                  nodes {
                    userId
                    totalCredits
                    creditsUsed
                    totalCreditsUsed
                    monthlyCommitmentCreditsUsed
                    monthlyWaiverCreditsUsed
                    overageCreditsUsed
                    paidTierTrialCreditsUsed
                    entityType
                  }
                  pageInfo {
                    hasNextPage
                    hasPreviousPage
                    startCursor
                    endCursor
                  }
                }
              }
            }
          }
        }
      GQL

      GET_CONSUMERS_WITHOUT_ENTITY_TYPE_QUERY = GET_CONSUMERS_QUERY.gsub(/^\s+entityType\n/, '')

      GET_USERS_USAGE_STATS_QUERY = <<~GQL
        query subscriptionUsageUsersStats(
          $instanceId: String,
          $namespaceId: ID,
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date,
          $flowTypes: [String!]
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(instanceId: $instanceId, startDate: $startDate, endDate: $endDate, flowTypes: $flowTypes) {
              usersUsage {
                totalActiveUsers
                totalUsersUsingCredits
                totalUsersUsingMonthlyCommitment
                totalUsersUsingOverage
                creditsUsed
                dailyUsage {
                  date
                  creditsUsed
                }
              }
            }
          }
        }
      GQL

      GET_TRIAL_USAGE_QUERY = <<~GQL
        query trialUsage(
          $namespaceId: ID,
          $licenseKey: String
        ) {
          trialUsage(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            activeTrial {
              startDate
              endDate
            }
            usersUsage {
              creditsUsed
              totalUsersUsingCredits
            }
          }
        }
      GQL

      GET_TRIAL_USAGE_FOR_USER_IDS_QUERY = <<~GQL
        query trialUsageForUserIds(
          $namespaceId: ID,
          $licenseKey: String,
          $userIds: [Int!]!
        ) {
          trialUsage(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            usersUsage {
              users(userIds: $userIds) {
                userId
                totalCredits
                creditsUsed
              }
            }
          }
        }
      GQL

      GET_BUDGET_CAPS_QUERY = <<~GQL
        query budgetCaps(
          $namespaceId: ID,
          $licenseKey: String,
          $entityIds: [String!],
          $first: Int,
          $last: Int,
          $after: String,
          $before: String
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            budgetControls {
              subscription {
                subscriptionName
                subscriptionCap
                subscriptionCapEnabled
                flatUserCap
                flatUserCapEnabled
              }
              userBudgetCapOverrides(
                entityIds: $entityIds,
                first: $first,
                last: $last,
                after: $after,
                before: $before
              ) {
                nodes {
                  entityId
                  cap
                  capEnabled
                  selfManagedInstanceActivationId
                  createdAt
                  updatedAt
                }
                pageInfo {
                  hasNextPage
                  hasPreviousPage
                  startCursor
                  endCursor
                }
              }
            }
          }
        }
      GQL

      UPSERT_USER_BUDGET_CAPS_MUTATION = <<~GQL
        mutation upsertUserBudgetCapsBulk(
          $input: UpsertUserBudgetCapsBulkInput!
        ) {
          upsertUserBudgetCapsBulk(input: $input) {
            userBudgetCapOverrides {
              entityId
              cap
              capEnabled
              selfManagedInstanceActivationId
            }
            errors
          }
        }
      GQL

      UPSERT_FLAT_USER_CAP_MUTATION = <<~GQL
        mutation upsertBudgetCapSubscription(
          $input: UpsertBudgetCapSubscriptionInput!
        ) {
          upsertBudgetCapSubscription(input: $input) {
            subscriptionBudgetCap {
              subscriptionName
              flatUserCap
              flatUserCapEnabled
            }
            errors
          }
        }
      GQL

      GET_PRODUCTS_QUERY = <<~GQL
        query subscriptionUsageProducts(
          $instanceId: String,
          $namespaceId: ID,
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(instanceId: $instanceId, startDate: $startDate, endDate: $endDate) {
              products {
                id
                title
                creditsUsed
                flowTypes {
                  id
                  title
                }
              }
            }
          }
        }
      GQL

      GET_BLOCKED_STATUSES_QUERY = <<~GQL
        query subscriptionBlockedStatuses(
          $instanceId: String,
          $namespaceId: ID,
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date,
          $entityIds: [String!]!
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(instanceId: $instanceId, startDate: $startDate, endDate: $endDate) {
              blockedStatuses(entityIds: $entityIds) {
                nodes {
                  entityId
                  blocked
                  capType
                }
              }
            }
          }
        }
      GQL

      # Initialize the client with the provided parameters that will be used later
      # to make API calls to the subscription portal
      #
      # @param namespace_id [Integer] The ID of the namespace, used when in GitLab.com
      # @param license_key [String] The license key to use for authentication in Self-Managed instances
      # @param start_date [String] The start date of the usage period (ISO 8601 format)
      # @param end_date [String] The end date of the usage period (ISO 8601 format)
      def initialize(
        namespace_id: nil,
        license_key: nil,
        start_date: Date.current.beginning_of_month.iso8601,
        end_date: Date.current.end_of_month.iso8601
      )
        @namespace_id = namespace_id
        @license_key = license_key
        @start_date = start_date
        @end_date = end_date
      end

      def get_metadata
        response = execute_graphql_query(
          query: GET_METADATA_QUERY,
          extra_variables: { gitlabVersion: Gitlab::VERSION }
        )

        if unsuccessful_response?(response)
          error(GET_METADATA_QUERY, response)
        else
          {
            success: true,
            subscriptionUsage: response.dig(:data, :subscription, :gitlabCreditsUsage)
          }
        end
      end
      strong_memoize_attr :get_metadata

      def get_subscription_usage(args = {})
        strong_memoize_with(:get_subscription_usage, args) do
          response = execute_graphql_query(
            query: GET_SUBSCRIPTION_USAGE_QUERY,
            extra_variables: {
              sort: args[:sort]&.upcase,
              limit: args[:limit],
              flowTypes: args[:flow_types].presence
            }.compact
          )

          if unsuccessful_response?(response)
            error(GET_SUBSCRIPTION_USAGE_QUERY, response)
          else
            {
              success: true,
              subscriptionUsage: response.dig(:data, :subscription, :gitlabCreditsUsage)
            }
          end
        end
      end

      def get_monthly_waiver
        response = execute_graphql_query(query: GET_MONTHLY_WAIVER_QUERY)

        if unsuccessful_response?(response)
          error(GET_MONTHLY_WAIVER_QUERY, response)
        else
          {
            success: true,
            monthlyWaiver: response.dig(:data, :subscription, :gitlabCreditsUsage, :monthlyWaiver)
          }
        end
      end

      def get_monthly_commitment
        response = execute_graphql_query(query: GET_MONTHLY_COMMITMENT_QUERY)

        if unsuccessful_response?(response)
          error(GET_MONTHLY_COMMITMENT_QUERY, response)
        else
          {
            success: true,
            monthlyCommitment: response.dig(:data, :subscription, :gitlabCreditsUsage, :monthlyCommitment)
          }
        end
      end
      strong_memoize_attr :get_monthly_commitment

      def get_overage
        response = execute_graphql_query(query: GET_OVERAGE_QUERY)

        if unsuccessful_response?(response)
          error(GET_OVERAGE_QUERY, response)
        else
          {
            success: true,
            overage: response.dig(:data, :subscription, :gitlabCreditsUsage, :overage)
          }
        end
      end
      strong_memoize_attr :get_overage

      def get_paid_tier_trial
        response = execute_graphql_query(query: GET_PAID_TIER_TRIAL_QUERY)

        if unsuccessful_response?(response)
          error(GET_PAID_TIER_TRIAL_QUERY, response)
        else
          {
            success: true,
            paidTierTrial: response.dig(:data, :subscription, :gitlabCreditsUsage, :paidTierTrial)
          }
        end
      end
      strong_memoize_attr :get_paid_tier_trial

      def get_products
        response = execute_graphql_query(query: GET_PRODUCTS_QUERY)

        if unsuccessful_response?(response)
          error(GET_PRODUCTS_QUERY, response)
        else
          {
            success: true,
            products: response.dig(:data, :subscription, :gitlabCreditsUsage, :products)
          }
        end
      end
      strong_memoize_attr :get_products

      def get_events_for_user_id(user_id, args)
        strong_memoize_with(:get_events_for_user_id, user_id, args) do
          response = execute_graphql_query(
            query: GET_USER_EVENTS_QUERY,
            extra_variables: {
              userIds: [user_id],
              flowTypes: args[:flow_types],
              first: args[:first],
              last: args[:last],
              before: args[:before],
              after: args[:after]
            }.compact
          )

          if unsuccessful_response?(response)
            error(GET_USER_EVENTS_QUERY, response)
          else
            user_events = response.dig(:data, :subscription, :gitlabCreditsUsage, :usersUsage, :users)
              .to_a.first&.fetch(:events)
            {
              success: true,
              userEvents: user_events
            }
          end
        end
      end

      def get_used_flow_types_for_user_id(user_id)
        strong_memoize_with(:get_used_flow_types_for_user_id, user_id) do
          response = execute_graphql_query(
            query: GET_USED_FLOW_TYPES_QUERY,
            extra_variables: { userIds: [user_id] }
          )

          if unsuccessful_response?(response)
            error(GET_USED_FLOW_TYPES_QUERY, response)
          else
            used_flow_types = response.dig(:data, :subscription, :gitlabCreditsUsage, :usersUsage, :users)
              .to_a.first&.fetch(:usedFlowTypes, nil)
            {
              success: true,
              usedFlowTypes: used_flow_types
            }
          end
        end
      end

      def get_usage_for_user_ids(user_ids, flow_types: nil)
        strong_memoize_with(:get_usage_for_user_ids, user_ids, flow_types) do
          response = execute_graphql_query(
            query: GET_USERS_USAGE_QUERY,
            extra_variables: { userIds: user_ids, flowTypes: flow_types.presence }
          )

          if unsuccessful_response?(response)
            error(GET_USERS_USAGE_QUERY, response)
          else
            {
              success: true,
              usersUsage: response.dig(:data, :subscription, :gitlabCreditsUsage, :usersUsage, :users)
            }
          end
        end
      end

      def get_consumers(args)
        strong_memoize_with(:get_consumers, args) do
          variables = {
            sort: args[:sort]&.upcase,
            first: args[:first],
            last: args[:last],
            before: args[:before],
            after: args[:after],
            flowTypes: args[:flow_types].presence
          }

          response = execute_graphql_query(query: GET_CONSUMERS_QUERY, extra_variables: variables)

          # Temporary compatibility fallback while CustomerDot deploys `entityType`.
          # Remove after CustomerDot supports `GitlabCreditsConsumer.entityType` (https://gitlab.com/gitlab-org/customers-gitlab-com/-/merge_requests/15645).
          if undefined_field_error?(response, 'entityType')
            response = execute_graphql_query(query: GET_CONSUMERS_WITHOUT_ENTITY_TYPE_QUERY, extra_variables: variables)
          end

          if unsuccessful_response?(response)
            error(GET_CONSUMERS_QUERY, response)
          else
            {
              success: true,
              consumers: response.dig(:data, :subscription, :gitlabCreditsUsage, :usersUsage, :consumers)
            }
          end
        end
      end

      def get_users_usage_stats(flow_types: nil)
        strong_memoize_with(:get_users_usage_stats, flow_types) do
          response = execute_graphql_query(
            query: GET_USERS_USAGE_STATS_QUERY,
            extra_variables: { flowTypes: flow_types.presence }.compact
          )

          if unsuccessful_response?(response)
            error(GET_USERS_USAGE_STATS_QUERY, response)
          else
            {
              success: true,
              usersUsage: response.dig(:data, :subscription, :gitlabCreditsUsage, :usersUsage)
            }
          end
        end
      end

      def get_trial_usage
        response = execute_graphql_query(query: GET_TRIAL_USAGE_QUERY)

        if unsuccessful_response?(response)
          error(GET_TRIAL_USAGE_QUERY, response)
        else
          {
            success: true,
            trialUsage: response.dig(:data, :trialUsage)
          }
        end
      end
      strong_memoize_attr :get_trial_usage

      def get_trial_usage_for_user_ids(user_ids)
        strong_memoize_with(:get_trial_usage_for_user_ids, user_ids) do
          response = execute_graphql_query(query: GET_TRIAL_USAGE_FOR_USER_IDS_QUERY,
            extra_variables: { userIds: user_ids })

          if unsuccessful_response?(response)
            error(GET_TRIAL_USAGE_FOR_USER_IDS_QUERY, response)
          else
            {
              success: true,
              usersUsage: response.dig(:data, :trialUsage, :usersUsage, :users)
            }
          end
        end
      end

      def get_budget_caps(entity_ids: nil, args: {})
        strong_memoize_with(:get_budget_caps, entity_ids, args) do
          variables = {
            instanceId: Gitlab::GlobalAnonymousId.instance_id,
            namespaceId: namespace_id,
            licenseKey: license_key,
            entityIds: entity_ids,
            first: args[:first],
            last: args[:last],
            before: args[:before],
            after: args[:after]
          }.compact

          response = execute_cdot_graphql(
            query: GET_BUDGET_CAPS_QUERY,
            variables: variables
          )

          if unsuccessful_response?(response)
            error(GET_BUDGET_CAPS_QUERY, response)
          else
            {
              success: true,
              budgetControls: response.dig(
                :data, :subscription, :budgetControls
              )
            }
          end
        end
      end

      def get_blocked_statuses(entity_ids)
        strong_memoize_with(:get_blocked_statuses, entity_ids) do
          response = execute_graphql_query(
            query: GET_BLOCKED_STATUSES_QUERY,
            extra_variables: { entityIds: entity_ids }
          )

          if unsuccessful_response?(response)
            error(GET_BLOCKED_STATUSES_QUERY, response)
          else
            {
              success: true,
              blockedStatuses: response.dig(
                :data, :subscription, :gitlabCreditsUsage, :blockedStatuses, :nodes
              )
            }
          end
        end
      end

      def upsert_user_budget_cap_overrides(overrides:)
        input = build_mutation_input(
          overrides: overrides,
          include_instance_id: true
        )

        execute_cdot_mutation(
          query: UPSERT_USER_BUDGET_CAPS_MUTATION,
          input: input,
          result_path: [:upsertUserBudgetCapsBulk],
          result_key: :userBudgetCapOverrides
        )
      end

      def upsert_flat_user_cap(flat_user_cap:, flat_user_cap_enabled:)
        input = build_mutation_input(
          flatUserCap: flat_user_cap,
          flatUserCapEnabled: flat_user_cap_enabled
        )

        execute_cdot_mutation(
          query: UPSERT_FLAT_USER_CAP_MUTATION,
          input: input,
          result_path: [:upsertBudgetCapSubscription],
          result_key: :subscriptionBudgetCap
        )
      end

      attr_reader :start_date, :end_date

      private

      attr_reader :namespace_id, :license_key

      def execute_graphql_query(query:, extra_variables: {})
        variables = {
          instanceId: Gitlab::GlobalAnonymousId.instance_id,
          namespaceId: namespace_id,
          licenseKey: license_key,
          startDate: start_date,
          endDate: end_date
        }.compact.merge(extra_variables)

        execute_cdot_graphql(query: query, variables: variables)
      end

      def build_mutation_input(include_instance_id: false, **fields)
        input = fields.dup

        unless license_key
          input[:namespaceId] = namespace_id
          return input
        end

        input[:licenseKey] = license_key
        input[:uniqueInstanceId] = Gitlab::GlobalAnonymousId.instance_id if include_instance_id

        input
      end

      def execute_cdot_mutation(query:, input:, result_path:, result_key:)
        response = execute_cdot_graphql(
          query: query,
          variables: { input: input }
        )

        return error(query, response) if unsuccessful_response?(response)

        mutation_data = response.dig(:data, *result_path)

        return error(query, response) if mutation_data.nil?
        return { success: false, errors: mutation_data[:errors] } if mutation_data[:errors].present?

        { success: true, result_key => mutation_data[result_key] }
      end

      def execute_cdot_graphql(query:, variables:)
        headers = license_key ? json_headers : admin_headers

        http_post_graphql(query: query, variables: variables, headers: headers)
      end

      def http_post_graphql(query:, variables:, headers:)
        http_response = ::Gitlab::HTTP.post(
          ::Gitlab::Routing.url_helpers.subscription_portal_graphql_url,
          headers: headers,
          body: { query: query, variables: variables }.to_json
        )

        if http_response.response.is_a?(Net::HTTPSuccess)
          http_response.parsed_response.deep_symbolize_keys
        else
          { data: { errors: http_response.response.message } }
        end
      end

      def unsuccessful_response?(response)
        return if response.dig(:data, :errors).blank? && response[:errors].blank?

        true
      end

      def undefined_field_error?(response, field_name)
        response.values_at(:errors, :data).to_s.include?("Field '#{field_name}' doesn't exist")
      end

      def error(query, response)
        Gitlab::ErrorTracking.track_and_raise_exception(
          ResponseError.new("Received an error from CustomerDot"),
          query: query,
          response: response
        )
      end

      def default_headers
        {
          "User-Agent" => "GitLab/#{Gitlab::VERSION}"
        }
      end

      def json_headers
        default_headers.merge(
          {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json'
          }
        )
      end

      def admin_headers
        json_headers.merge(
          {
            'X-Admin-Email' => Gitlab::SubscriptionPortal::SUBSCRIPTION_PORTAL_ADMIN_EMAIL,
            'X-Admin-Token' => Gitlab::SubscriptionPortal::SUBSCRIPTION_PORTAL_ADMIN_TOKEN
          }
        )
      end
    end
  end
end
