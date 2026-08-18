# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.subscriptionUsage', feature_category: :consumables_cost_management do
  include GraphqlHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:owner) { create(:user, :with_namespace) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:subgroup_user) { create(:user) }
  let_it_be(:bot) { create(:user, :bot) }
  let_it_be(:root_group) { create(:group, owners: owner, maintainers: maintainer, developers: bot) }
  let_it_be(:subgroup) { create(:group, parent: root_group, owners: owner, developers: subgroup_user) }
  let_it_be(:project) { create(:project, namespace: owner.namespace) }
  let_it_be(:user_namespace) { create(:user_namespace, owner: owner) }

  let(:error_message) do
    "The resource that you are attempting to access does not exist or you don't have permission to perform this action"
  end

  let(:user_events) do
    {
      nodes: [
        {
          timestamp: "2025-10-01T16:25:28Z",
          eventType: "ai_token_usage",
          flowType: "Software Development Flow",
          location: nil,
          creditsUsed: 12.5,
          sessionLink: nil
        },
        {
          timestamp: "2025-10-01T16:30:12Z",
          eventType: "workflow_execution",
          flowType: "Convert to GitLab CI/CD Flow",
          location: { fullPath: project.full_path },
          creditsUsed: 25.32,
          sessionLink: "#{Gitlab::Routing.url_helpers.project_automate_agent_sessions_url(project)}/100"
        },
        {
          timestamp: "2025-10-01T16:52:28Z",
          eventType: "ai_token_usage",
          flowType: "Agentic Chat",
          location: { fullPath: project.full_path },
          creditsUsed: 13.33,
          sessionLink: nil
        },
        {
          timestamp: "2025-10-01T22:30:12Z",
          eventType: "workflow_execution",
          flowType: "Code Review Flow",
          location: { fullPath: project.full_path },
          creditsUsed: 1,
          sessionLink: nil
        }
      ],
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: "2025-10-01T16:25:28Z",
        endCursor: "2025-10-01T16:30:12Z"
      }
    }
  end

  let(:user_arguments) { {} }
  let(:query_fields) do
    [
      :enabled,
      :is_outdated_client,
      :last_event_transaction_at,
      :start_date,
      :end_date,
      query_graphql_field(:monthly_waiver, {}, [
        :total_credits,
        :credits_used,
        query_graphql_field(:daily_usage, {}, [:date, :credits_used])
      ]),
      :purchase_credits_path,
      query_graphql_field(:monthly_commitment, {}, [
        :total_credits,
        :credits_used,
        query_graphql_field(:daily_usage, {}, [:date, :credits_used])
      ]),
      query_graphql_field(:overage, {}, [
        :is_allowed,
        :credits_used,
        query_graphql_field(:daily_usage, {}, [:date, :credits_used])
      ]),
      :daily_average,
      query_graphql_field(:daily_usage, 'sort: DATE_ASC, limit: 5', [:date, :credits_used]),
      query_graphql_field(:users_usage, {}, [
        :total_active_users,
        :total_users_using_credits,
        :total_users_using_monthly_commitment,
        :total_users_using_overage,
        :credits_used,
        query_graphql_field(:daily_usage, {}, [:date, :credits_used]),
        query_nodes(
          :users,
          [
            :id,
            :name,
            :username,
            :avatar_url,
            query_graphql_field(:usage, {}, [
              :total_credits,
              :credits_used,
              :monthly_commitment_credits_used,
              :monthly_waiver_credits_used,
              :overage_credits_used,
              :paid_tier_trial_credits_used
            ]),
            query_nodes(
              :events,
              [
                :timestamp,
                :event_type,
                :flow_type,
                query_graphql_field(:location, {}, [
                  '... on Group { fullPath }',
                  '... on Project { fullPath }'
                ]),
                :credits_used,
                :session_link
              ],
              include_pagination_info: true
            ),
            query_graphql_field(:blocked_status, {}, [
              :blocked,
              :cap_type
            ])
          ],
          args: user_arguments
        )
      ]),
      query_graphql_field(:paid_tier_trial, {}, [
        :is_active,
        query_graphql_field(:daily_usage, {}, [:date, :credits_used])
      ])
    ]
  end

  let(:query_start_date) { nil }
  let(:query_end_date) { nil }
  let(:query_flow_types) { nil }

  let(:query) do
    graphql_query_for(
      :subscription_usage,
      {
        namespace_path: namespace_path,
        start_date: query_start_date,
        end_date: query_end_date,
        flow_types: query_flow_types
      }.compact,
      query_fields
    )
  end

  let(:metadata) do
    {
      success: true,
      subscriptionUsage: {
        startDate: "2025-10-01",
        endDate: "2025-10-31",
        enabled: true,
        isOutdatedClient: false,
        lastEventTransactionAt: "2025-10-01T16:19:59Z"
      }
    }
  end

  shared_examples 'empty response' do
    it 'returns nil for subscription usage' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data_at(:subscription_usage)).to be_nil
    end

    it 'returns an error message' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to include(a_hash_including('message' => error_message))
    end
  end

  before do
    events_for_user_id = {
      nodes: [
        {
          timestamp: "2025-10-01T16:25:28Z",
          eventType: "ai_token_usage",
          flowType: "Software Development Flow",
          projectId: nil,
          namespaceId: nil,
          creditsUsed: 12.5,
          sessionId: 300,
          showSessionLink: true
        },
        {
          timestamp: "2025-10-01T16:30:12Z",
          eventType: "workflow_execution",
          flowType: "Convert to GitLab CI/CD Flow",
          projectId: project.id,
          namespaceId: nil,
          creditsUsed: 25.32,
          sessionId: 100,
          showSessionLink: true
        },
        {
          timestamp: "2025-10-01T16:52:28Z",
          eventType: "ai_token_usage",
          flowType: "Agentic Chat",
          projectId: project.id,
          namespaceId: root_group.id,
          creditsUsed: 13.33,
          sessionId: nil,
          showSessionLink: true
        },
        {
          timestamp: "2025-10-01T22:30:12Z",
          eventType: "workflow_execution",
          flowType: "Code Review Flow",
          projectId: project.id,
          namespaceId: root_group.id,
          creditsUsed: 1,
          sessionId: 200,
          showSessionLink: false
        }
      ],
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: "2025-10-01T16:25:28Z",
        endCursor: "2025-10-01T16:30:12Z"
      }
    }

    users_usage = User.all.map do |user|
      {
        userId: user.id,
        totalCredits: (user.id * 1.25).round(2),
        creditsUsed: (user.id * 10.45).round(2),
        monthlyCommitmentCreditsUsed: (user.id * 5.25).round(2),
        monthlyWaiverCreditsUsed: (user.id * 1.35).round(2),
        overageCreditsUsed: (user.id * 2.55).round(2),
        paidTierTrialCreditsUsed: (user.id * 0.75).round(2)
      }
    end

    users_usage_stats = {
      success: true,
      usersUsage: {
        totalActiveUsers: 5,
        totalUsersUsingCredits: 3,
        totalUsersUsingMonthlyCommitment: 2,
        totalUsersUsingOverage: 1,
        creditsUsed: 123.45,
        dailyUsage: [{ date: '2025-10-01', creditsUsed: 321 }]
      }
    }

    monthly_waiver = {
      success: true,
      monthlyWaiver: {
        totalCredits: 1000.5,
        creditsUsed: 15.32,
        dailyUsage: [{ date: '2025-10-01', creditsUsed: 15.32 }]
      }
    }

    monthly_commitment = {
      success: true,
      monthlyCommitment: {
        totalCredits: 1000.89,
        creditsUsed: 250.91,
        dailyUsage: [{ date: '2025-10-01', creditsUsed: 250.91 }]
      }
    }

    overage = {
      success: true,
      overage: {
        isAllowed: true,
        creditsUsed: 150.12,
        dailyUsage: [{ date: '2025-10-01', creditsUsed: 150.12 }]
      }
    }

    paid_tier_trial = {
      success: true,
      paidTierTrial: {
        isActive: true,
        dailyUsage: [{ date: '2025-10-01', creditsUsed: 93.28 }]
      }
    }

    allow_next_instance_of(Gitlab::SubscriptionPortal::SubscriptionUsageClient) do |client|
      allow(client).to receive(:get_subscription_usage).and_return(
        {
          success: true,
          subscriptionUsage: {
            creditsUsed: 287.45,
            dailyAverage: 143.73,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 287.45 }]
          }
        }
      )

      allow(client).to receive(:get_subscription_usage).with(hash_including(sort: :date_asc, limit: 5)).and_return(
        {
          success: true,
          subscriptionUsage: {
            creditsUsed: 287.45,
            dailyAverage: 143.73,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 287.45 }]
          }
        }
      )

      allow(client).to receive_messages(
        get_metadata: metadata,
        get_monthly_waiver: monthly_waiver,
        get_monthly_commitment: monthly_commitment,
        get_overage: overage,
        get_events_for_user_id: { success: true, userEvents: events_for_user_id },
        get_usage_for_user_ids: { success: true, usersUsage: users_usage },
        get_users_usage_stats: users_usage_stats,
        get_paid_tier_trial: paid_tier_trial,
        get_blocked_statuses: {
          success: true,
          blockedStatuses: users_usage.map do |usage|
            {
              entityId: usage[:userId].to_s,
              blocked: usage[:userId].even?,
              capType: usage[:userId].even? ? 'FLAT_USER_CAP' : nil
            }
          end
        }
      )
    end
  end

  context 'when in Self-Managed' do
    let(:namespace_path) { nil }

    context 'with admin user' do
      context 'when feature flag is enabled' do
        let!(:subscription_name) { 'A-S00000001' }
        let(:gitlab_license) { build(:gitlab_license, restrictions: { subscription_name: subscription_name }) }
        let(:license) { create(:license, data: gitlab_license.export) }

        before do
          allow(License).to receive(:current).and_return(license)
          post_graphql(query, current_user: admin)
        end

        it 'returns subscription usage for instance' do
          expect(graphql_data_at(:subscription_usage, :enabled)).to be true
          expect(graphql_data_at(:subscription_usage, :isOutdatedClient)).to be false
          expect(graphql_data_at(:subscription_usage, :lastEventTransactionAt)).to eq("2025-10-01T16:19:59Z")
          expect(graphql_data_at(:subscription_usage, :startDate)).to eq("2025-10-01")
          expect(graphql_data_at(:subscription_usage, :endDate)).to eq("2025-10-31")
          expect(graphql_data_at(:subscription_usage, :purchaseCreditsPath))
              .to eq("/subscriptions/purchases/gitlab?deployment_type=self_managed" \
                "&plan_type=gitlab_credits&subscription_name=A-S00000001")
          expect(graphql_data_at(:subscription_usage, :dailyAverage)).to eq(143.73)

          expect(graphql_data_at(:subscription_usage, :monthlyWaiver)).to eq({
            totalCredits: 1000.5,
            creditsUsed: 15.32,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 15.32 }]
          }.with_indifferent_access)

          expect(graphql_data_at(:subscription_usage, :monthlyCommitment)).to eq({
            totalCredits: 1000.89,
            creditsUsed: 250.91,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 250.91 }]
          }.with_indifferent_access)

          expect(graphql_data_at(:subscription_usage, :overage)).to eq({
            isAllowed: true,
            creditsUsed: 150.12,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 150.12 }]
          }.with_indifferent_access)

          expect(graphql_data_at(:subscription_usage, :usersUsage, :totalActiveUsers)).to eq(5)
          expect(graphql_data_at(:subscription_usage, :usersUsage, :totalUsersUsingCredits)).to eq(3)
          expect(graphql_data_at(:subscription_usage, :usersUsage, :totalUsersUsingMonthlyCommitment)).to eq(2)
          expect(graphql_data_at(:subscription_usage, :usersUsage, :totalUsersUsingOverage)).to eq(1)
          expect(graphql_data_at(:subscription_usage, :usersUsage, :creditsUsed)).to eq(123.45)
          expect(graphql_data_at(:subscription_usage, :usersUsage, :dailyUsage))
            .to match_array([{ date: '2025-10-01', creditsUsed: 321 }.with_indifferent_access])

          expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to match_array(
            User.all.without_bots.map do |u|
              {
                id: u.to_global_id.to_s,
                name: u.name,
                username: u.username,
                avatarUrl: u.avatar_url,
                usage: {
                  totalCredits: (u.id * 1.25).round(2),
                  creditsUsed: (u.id * 10.45).round(2),
                  monthlyCommitmentCreditsUsed: (u.id * 5.25).round(2),
                  monthlyWaiverCreditsUsed: (u.id * 1.35).round(2),
                  overageCreditsUsed: (u.id * 2.55).round(2),
                  paidTierTrialCreditsUsed: (u.id * 0.75).round(2)
                },
                blockedStatus: {
                  blocked: u.id.even?,
                  capType: u.id.even? ? 'FLAT_USER_CAP' : nil
                },
                events: nil
              }.with_indifferent_access
            end
          )

          expect(graphql_data_at(:subscription_usage, :paidTierTrial)).to eq({
            isActive: true,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 93.28 }]
          }.with_indifferent_access)
        end

        context 'when the CustomersDot subscription_usage API is not enabled' do
          let(:query_fields) { [:enabled] }
          let(:metadata) do
            {
              success: true,
              subscriptionUsage: {
                enabled: false
              }
            }
          end

          it 'does not return subscription usage data' do
            expect(graphql_data_at(:subscription_usage, :enabled)).to be false
            expect(graphql_data_at(:subscription_usage, :purchaseCreditsPath)).to be_nil
            expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to be_nil
          end
        end

        context 'when subscription can accept overage terms' do
          let(:query_fields) do
            [:overage_terms_accepted, :can_accept_overage_terms, :dap_promo_enabled,
              :subscription_portal_usage_dashboard_url]
          end

          let(:metadata) do
            {
              success: true,
              subscriptionUsage: {
                overageTermsAccepted: false,
                canAcceptOverageTerms: true,
                dapPromoEnabled: false,
                usageDashboardPath: "/subscriptions/A-S00012345/usage"
              }
            }
          end

          it 'exposes acceptance flags and dashboard URL correctly' do
            post_graphql(query, current_user: admin)

            expect(graphql_data_at(:subscription_usage, :overageTermsAccepted)).to be false
            expect(graphql_data_at(:subscription_usage, :canAcceptOverageTerms)).to be true
            expect(graphql_data_at(:subscription_usage, :dapPromoEnabled)).to be false

            expect(graphql_data_at(:subscription_usage, :subscriptionPortalUsageDashboardUrl)).to eq(
              'https://customers.gitlab.com/subscriptions/A-S00012345/usage'
            )
          end
        end

        context 'when subscription cannot accept overage terms' do
          let(:query_fields) { [:can_accept_overage_terms, :subscription_portal_usage_dashboard_url] }

          let(:metadata) do
            {
              success: true,
              subscriptionUsage: {
                canAcceptOverageTerms: false,
                usageDashboardPath: '/subscriptions/A-S00012345/usage'
              }
            }
          end

          it 'returns false and no dashboard URL' do
            expect(graphql_data_at(:subscription_usage, :canAcceptOverageTerms)).to be false
            expect(graphql_data_at(:subscription_usage, :subscriptionPortalUsageDashboardUrl)).to be_nil
          end
        end

        context 'when usage dashboard path is blank' do
          let(:query_fields) { [:subscription_portal_usage_dashboard_url] }

          let(:metadata) do
            {
              success: true,
              subscriptionUsage: {
                canAcceptOverageTerms: true,
                usageDashboardPath: nil
              }
            }
          end

          it 'returns nil subscriptionPortalUsageDashboardUrl' do
            post_graphql(query, current_user: admin)

            expect(graphql_data_at(:subscription_usage, :subscriptionPortalUsageDashboardUrl)).to be_nil
          end
        end

        context 'when DAP promo is enabled' do
          let(:query_fields) { [:dap_promo_enabled] }

          let(:metadata) do
            {
              success: true,
              subscriptionUsage: {
                dapPromoEnabled: true
              }
            }
          end

          it 'returns true for dapPromoEnabled' do
            post_graphql(query, current_user: admin)

            expect(graphql_data_at(:subscription_usage, :dapPromoEnabled)).to be true
          end
        end

        context 'when DAP promo is disabled' do
          let(:query_fields) { [:dap_promo_enabled] }

          let(:metadata) do
            {
              success: true,
              subscriptionUsage: {
                dapPromoEnabled: false
              }
            }
          end

          it 'returns false for dapPromoEnabled' do
            post_graphql(query, current_user: admin)

            expect(graphql_data_at(:subscription_usage, :dapPromoEnabled)).to be false
          end
        end

        context 'when overage terms are accepted' do
          let(:query_fields) { [:overage_terms_accepted] }

          let(:metadata) do
            {
              success: true,
              subscriptionUsage: {
                overageTermsAccepted: true
              }
            }
          end

          it 'returns true for overageTermsAccepted' do
            post_graphql(query, current_user: admin)

            expect(graphql_data_at(:subscription_usage, :overageTermsAccepted)).to be true
          end
        end

        context 'when overage terms are not accepted' do
          let(:query_fields) { [:overage_terms_accepted] }

          let(:metadata) do
            {
              success: true,
              subscriptionUsage: {
                overageTermsAccepted: false
              }
            }
          end

          it 'returns false for overageTermsAccepted' do
            post_graphql(query, current_user: admin)

            expect(graphql_data_at(:subscription_usage, :overageTermsAccepted)).to be false
          end
        end

        context 'when filtering users by username' do
          let(:user_arguments) { { username: maintainer.username } }

          it 'returns user data for the specified user only' do
            expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to match_array([
              {
                id: maintainer.to_global_id.to_s,
                name: maintainer.name,
                username: maintainer.username,
                avatarUrl: maintainer.avatar_url,
                usage: {
                  totalCredits: (maintainer.id * 1.25).round(2),
                  creditsUsed: (maintainer.id * 10.45).round(2),
                  monthlyCommitmentCreditsUsed: (maintainer.id * 5.25).round(2),
                  monthlyWaiverCreditsUsed: (maintainer.id * 1.35).round(2),
                  overageCreditsUsed: (maintainer.id * 2.55).round(2),
                  paidTierTrialCreditsUsed: (maintainer.id * 0.75).round(2)
                },
                blockedStatus: {
                  blocked: maintainer.id.even?,
                  capType: maintainer.id.even? ? 'FLAT_USER_CAP' : nil
                },
                events: user_events
              }.with_indifferent_access
            ])
          end

          context 'when user is a bot' do
            let(:user_arguments) { { username: bot.username } }

            it 'returns nothing on the users node' do
              expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to be_empty
            end
          end
        end

        context 'when filtering non-existent username' do
          let(:user_arguments) { { username: 'non-existent' } }

          it 'returns empty for user data' do
            expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to be_empty
          end
        end

        context 'with date filters' do
          let(:query_start_date) { '2025-10-01' }
          let(:query_end_date) { '2025-10-31' }
          let(:query_fields) { [:enabled, :start_date, :end_date] }

          before do
            post_graphql(query, current_user: admin)
          end

          it 'returns subscription usage with date-filtered data' do
            expect(graphql_data_at(:subscription_usage, :enabled)).to be true
            expect(graphql_data_at(:subscription_usage, :startDate)).to eq('2025-10-01')
            expect(graphql_data_at(:subscription_usage, :endDate)).to eq('2025-10-31')
          end
        end

        context 'when date range exceeds one year' do
          let(:query_start_date) { '2024-01-01' }
          let(:query_end_date) { '2025-01-02' }
          let(:query_fields) { [:enabled] }

          it 'returns an error' do
            post_graphql(query, current_user: admin)

            expect(graphql_errors).to include(
              a_hash_including('message' => 'Date range cannot exceed 1 year')
            )
          end
        end

        context 'when end_date is before start_date' do
          let(:query_start_date) { '2025-10-31' }
          let(:query_end_date) { '2025-10-01' }
          let(:query_fields) { [:enabled] }

          it 'returns an error' do
            post_graphql(query, current_user: admin)

            expect(graphql_errors).to include(
              a_hash_including('message' => 'end_date must be after or equal to start_date')
            )
          end
        end

        context 'when date range is exactly one year' do
          let(:query_start_date) { '2025-01-01' }
          let(:query_end_date) { '2026-01-01' }
          let(:query_fields) { [:enabled] }

          before do
            post_graphql(query, current_user: admin)
          end

          it 'returns subscription usage successfully' do
            expect(graphql_errors).to be_nil
            expect(graphql_data_at(:subscription_usage, :enabled)).to be true
          end
        end

        context 'when date range spans a leap year' do
          let(:query_start_date) { '2024-01-01' }
          let(:query_end_date) { '2025-01-01' }
          let(:query_fields) { [:enabled] }

          before do
            post_graphql(query, current_user: admin)
          end

          it 'returns subscription usage successfully despite 366 days' do
            expect(graphql_errors).to be_nil
            expect(graphql_data_at(:subscription_usage, :enabled)).to be true
          end
        end

        context 'when no dates are provided', :freeze_time do
          let(:expected_start_date) { Date.current.beginning_of_month.iso8601 }
          let(:expected_end_date) { Date.current.iso8601 }
          let(:query_fields) { [:enabled, :start_date, :end_date] }

          let(:metadata) do
            {
              success: true,
              subscriptionUsage: {
                enabled: true,
                startDate: expected_start_date,
                endDate: expected_end_date
              }
            }
          end

          it 'defaults to the current month clamped to today' do
            expect(Gitlab::SubscriptionPortal::SubscriptionUsageClient).to receive(:new)
              .with(hash_including(start_date: expected_start_date, end_date: expected_end_date))

            post_graphql(query, current_user: admin)

            expect(graphql_data_at(:subscription_usage, :startDate)).to eq(expected_start_date)
            expect(graphql_data_at(:subscription_usage, :endDate)).to eq(expected_end_date)
          end
        end

        context 'when no dates are provided on the first day of the month' do
          let(:query_fields) { [:enabled, :start_date, :end_date] }

          it 'uses a one-day range' do
            travel_to(Date.new(2026, 5, 1)) do
              expect(Gitlab::SubscriptionPortal::SubscriptionUsageClient).to receive(:new)
                .with(hash_including(start_date: '2026-05-01', end_date: '2026-05-01'))

              post_graphql(query, current_user: admin)
            end
          end
        end

        context 'when filtering by flow_types' do
          let(:query_fields) { [:credits_used] }
          let(:query_flow_types) { %w[chat] }

          it 'passes flow_types to the client' do
            allow_next_instance_of(Gitlab::SubscriptionPortal::SubscriptionUsageClient) do |client|
              expect(client).to receive(:get_subscription_usage)
                .with(hash_including(flow_types: %w[chat]))
                .and_return({ success: true, subscriptionUsage: { creditsUsed: 42.0 } })
            end

            expect(GitlabSubscriptions::SubscriptionUsage).to receive(:new)
              .with(hash_including(flow_types: %w[chat]))
              .and_call_original

            post_graphql(query, current_user: admin)

            expect(graphql_data_at(:subscription_usage, :creditsUsed)).to eq(42.0)
          end
        end
      end
    end

    context 'with non-admin user' do
      include_examples 'empty response' do
        let(:current_user) { owner }
      end
    end
  end

  context 'when in GitLab.com', :saas_gitlab_com_subscriptions do
    context 'with root group' do
      let(:namespace_path) { root_group.full_path }

      context 'when user is group owner' do
        context 'when feature flag is enabled' do
          before do
            post_graphql(query, current_user: owner)
          end

          it 'returns subscription usage for the group' do
            expect(graphql_data_at(:subscription_usage, :enabled)).to be true
            expect(graphql_data_at(:subscription_usage, :isOutdatedClient)).to be false
            expect(graphql_data_at(:subscription_usage, :lastEventTransactionAt)).to eq("2025-10-01T16:19:59Z")
            expect(graphql_data_at(:subscription_usage, :startDate)).to eq("2025-10-01")
            expect(graphql_data_at(:subscription_usage, :endDate)).to eq("2025-10-31")
            expect(graphql_data_at(:subscription_usage, :purchaseCreditsPath))
              .to eq("/subscriptions/purchases/gitlab?deployment_type=gitlab_com" \
                "&gl_namespace_id=#{root_group.id}&plan_type=gitlab_credits")
            expect(graphql_data_at(:subscription_usage, :dailyAverage)).to eq(143.73)

            expect(graphql_data_at(:subscription_usage, :monthlyWaiver)).to eq({
              totalCredits: 1000.5,
              creditsUsed: 15.32,
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 15.32 }]
            }.with_indifferent_access)

            expect(graphql_data_at(:subscription_usage, :monthlyCommitment)).to eq({
              totalCredits: 1000.89,
              creditsUsed: 250.91,
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 250.91 }]
            }.with_indifferent_access)

            expect(graphql_data_at(:subscription_usage, :overage)).to eq({
              isAllowed: true,
              creditsUsed: 150.12,
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 150.12 }]
            }.with_indifferent_access)

            expect(graphql_data_at(:subscription_usage, :usersUsage, :totalActiveUsers)).to eq(5)
            expect(graphql_data_at(:subscription_usage, :usersUsage, :totalUsersUsingCredits)).to eq(3)
            expect(graphql_data_at(:subscription_usage, :usersUsage, :totalUsersUsingMonthlyCommitment)).to eq(2)
            expect(graphql_data_at(:subscription_usage, :usersUsage, :totalUsersUsingOverage)).to eq(1)
            expect(graphql_data_at(:subscription_usage, :usersUsage, :creditsUsed)).to eq(123.45)
            expect(graphql_data_at(:subscription_usage, :usersUsage, :dailyUsage))
              .to match_array([{ date: '2025-10-01', creditsUsed: 321 }.with_indifferent_access])

            expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to match_array(
              root_group.users_with_descendants.without_bots.map do |u|
                {
                  id: u.to_global_id.to_s,
                  name: u.name,
                  username: u.username,
                  avatarUrl: u.avatar_url,
                  usage: {
                    totalCredits: (u.id * 1.25).round(2),
                    creditsUsed: (u.id * 10.45).round(2),
                    monthlyCommitmentCreditsUsed: (u.id * 5.25).round(2),
                    monthlyWaiverCreditsUsed: (u.id * 1.35).round(2),
                    overageCreditsUsed: (u.id * 2.55).round(2),
                    paidTierTrialCreditsUsed: (u.id * 0.75).round(2)
                  },
                  blockedStatus: {
                    blocked: u.id.even?,
                    capType: u.id.even? ? 'FLAT_USER_CAP' : nil
                  },
                  events: nil
                }.with_indifferent_access
              end
            )

            expect(graphql_data_at(:subscription_usage, :paidTierTrial)).to eq({
              isActive: true,
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 93.28 }]
            }.with_indifferent_access)
          end

          context 'when the CustomersDot subscription_usage API is not enabled' do
            let(:query_fields) { [:enabled] }
            let(:metadata) do
              {
                success: true,
                subscriptionUsage: {
                  enabled: false
                }
              }
            end

            it 'returns subscription usage for the group' do
              expect(graphql_data_at(:subscription_usage, :enabled)).to be false
            end
          end

          context 'when filtering users by username' do
            let(:user_arguments) { { username: maintainer.username } }

            it 'returns user data for the specified user only' do
              expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to match_array([
                {
                  id: maintainer.to_global_id.to_s,
                  name: maintainer.name,
                  username: maintainer.username,
                  avatarUrl: maintainer.avatar_url,
                  usage: {
                    totalCredits: (maintainer.id * 1.25).round(2),
                    creditsUsed: (maintainer.id * 10.45).round(2),
                    monthlyCommitmentCreditsUsed: (maintainer.id * 5.25).round(2),
                    monthlyWaiverCreditsUsed: (maintainer.id * 1.35).round(2),
                    overageCreditsUsed: (maintainer.id * 2.55).round(2),
                    paidTierTrialCreditsUsed: (maintainer.id * 0.75).round(2)
                  },
                  blockedStatus: {
                    blocked: maintainer.id.even?,
                    capType: maintainer.id.even? ? 'FLAT_USER_CAP' : nil
                  },
                  events: user_events
                }.with_indifferent_access
              ])
            end

            context 'when user is a subgroup member' do
              let(:user_arguments) { { username: subgroup_user.username } }

              it 'returns user data for the subgroup member' do
                expect(graphql_data_at(:subscription_usage, :purchaseCreditsPath))
                  .to eq("/subscriptions/purchases/gitlab?deployment_type=gitlab_com" \
                    "&gl_namespace_id=#{root_group.id}&plan_type=gitlab_credits")
                expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to match_array([
                  {
                    id: subgroup_user.to_global_id.to_s,
                    name: subgroup_user.name,
                    username: subgroup_user.username,
                    avatarUrl: subgroup_user.avatar_url,
                    usage: {
                      totalCredits: (subgroup_user.id * 1.25).round(2),
                      creditsUsed: (subgroup_user.id * 10.45).round(2),
                      monthlyCommitmentCreditsUsed: (subgroup_user.id * 5.25).round(2),
                      monthlyWaiverCreditsUsed: (subgroup_user.id * 1.35).round(2),
                      overageCreditsUsed: (subgroup_user.id * 2.55).round(2),
                      paidTierTrialCreditsUsed: (subgroup_user.id * 0.75).round(2)
                    },
                    blockedStatus: {
                      blocked: subgroup_user.id.even?,
                      capType: subgroup_user.id.even? ? 'FLAT_USER_CAP' : nil
                    },
                    events: user_events
                  }.with_indifferent_access
                ])
              end
            end

            context 'when user is a bot' do
              let(:user_arguments) { { username: bot.username } }

              it 'returns nothing on the users node' do
                expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to be_empty
              end
            end
          end

          context 'when filtering a username that is not a group member' do
            let(:user_arguments) { { username: admin.username } }

            it 'returns empty for user data' do
              expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to be_empty
            end
          end

          context 'when filtering non-existent username' do
            let(:user_arguments) { { username: 'non-existent' } }

            it 'returns empty for user data' do
              expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to be_empty
            end
          end
        end
      end

      context 'when user is not group owner' do
        include_examples 'empty response' do
          let(:current_user) { maintainer }
        end
      end
    end

    context 'with subgroup' do
      let(:namespace_path) { subgroup.full_path }

      include_examples 'empty response' do
        let(:current_user) { owner }
        let(:error_message) { "Subscription usage can only be queried on a root namespace" }
      end
    end

    context 'with project namespace' do
      let(:namespace_path) { project.namespace.full_path }

      include_examples 'empty response' do
        let(:current_user) { owner }
      end
    end

    context 'with user namespace' do
      let(:namespace_path) { user_namespace.full_path }

      include_examples 'empty response' do
        let(:current_user) { owner }
      end
    end

    context 'with non-existent namespace' do
      let(:namespace_path) { 'non-existent-namespace' }

      include_examples 'empty response' do
        let(:current_user) { admin }
      end
    end
  end
end
