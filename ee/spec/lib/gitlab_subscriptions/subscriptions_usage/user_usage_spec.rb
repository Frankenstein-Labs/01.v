# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionsUsage::UserUsage, feature_category: :consumables_cost_management do
  let_it_be(:non_group_member_user) { create(:user) }
  let_it_be(:active_user) { create(:user, name: 'Steve Jobs', username: 'active_user', email: 'firstuser@email.test') }
  let_it_be(:active_user2) { create(:user, name: 'active_user', username: 'user_active') }
  let_it_be(:service_user) { create(:user, :service_user, username: 'service_user') }
  let_it_be(:subgroup_user) { create(:user, name: 'Steve Wozniak') }
  let_it_be(:service_account) { create(:user, :service_account, username: 'service_account') }
  let_it_be(:bot) { create(:user, :bot) }
  let_it_be(:direct_group_members) { [active_user, active_user2, service_user] }
  let_it_be(:group) { create(:group, developers: direct_group_members + [bot]) }
  let_it_be(:subgroup) { create(:group, parent: group, developers: subgroup_user) }
  let_it_be(:project_user) { create(:user) }
  let_it_be(:project) { create(:project, namespace: subgroup, creator: active_user, developers: project_user) }
  let_it_be(:full_group_user_list) { direct_group_members + [subgroup_user, project_user] }

  let(:subscription_usage) { instance_double(GitlabSubscriptions::SubscriptionUsage) }
  let(:subscription_usage_client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }
  let(:client_response) do
    {
      success: true,
      usersUsage: {
        totalUsersUsingCredits: 3,
        totalUsersUsingMonthlyCommitment: 2,
        totalUsersUsingOverage: 1,
        creditsUsed: 123.45,
        dailyUsage: [{ date: '2025-10-01', creditsUsed: 321 }]
      }
    }
  end

  subject(:user_usage) { described_class.new(subscription_usage: subscription_usage) }

  before do
    allow(subscription_usage).to receive(:subscription_usage_client).and_return(subscription_usage_client)
  end

  describe "#daily_usage" do
    before do
      allow(subscription_usage_client).to receive(:get_users_usage_stats).and_return(client_response)
    end

    context 'when the client returns a successful response' do
      let(:client_response) do
        {
          success: true,
          usersUsage: { dailyUsage: [{ date: '2025-10-01', creditsUsed: 321 }] }
        }
      end

      it 'returns the correct daily usage' do
        expect(user_usage.daily_usage).to be_a(Array)
        expect(user_usage.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
        expect(user_usage.daily_usage.first).to have_attributes(
          date: '2025-10-01',
          credits_used: 321,
          declarative_policy_subject: subscription_usage
        )
      end
    end

    context 'when the client returns an unsuccessful response' do
      let(:client_response) { { success: false } }

      it 'returns an empty array for daily usage' do
        expect(user_usage.daily_usage).to be_a(Array)
        expect(user_usage.daily_usage).to be_empty
      end
    end

    context 'when the client response is missing the data' do
      let(:client_response) { { success: true, usersUsage: nil } }

      it 'returns an empty array for daily usage' do
        expect(user_usage.daily_usage).to be_a(Array)
        expect(user_usage.daily_usage).to be_empty
      end
    end
  end

  describe "#total_active_users" do
    before do
      allow(subscription_usage_client).to receive(:get_users_usage_stats).and_return(client_response)
    end

    context 'when the client returns a successful response' do
      let(:client_response) { { success: true, usersUsage: { totalActiveUsers: 5 } } }

      it 'returns the correct data' do
        expect(user_usage.total_active_users).to eq(5)
      end
    end

    context 'when flow_types are provided' do
      let(:client_response) { { success: true, usersUsage: { totalActiveUsers: 4 } } }

      it 'passes flow_types to the client' do
        expect(user_usage.total_active_users(flow_types: %w[chat])).to eq(4)

        expect(subscription_usage_client)
          .to have_received(:get_users_usage_stats)
                .with(flow_types: %w[chat])
      end
    end

    context 'when flow_types is empty' do
      let(:client_response) { { success: true, usersUsage: { totalActiveUsers: 5 } } }

      it 'passes nil to the client' do
        user_usage.total_active_users(flow_types: [])

        expect(subscription_usage_client)
          .to have_received(:get_users_usage_stats)
                .with(flow_types: nil)
      end
    end

    context 'when the client returns an unsuccessful response' do
      let(:client_response) { { success: false } }

      it 'returns nil' do
        expect(user_usage.total_active_users).to be_nil
      end
    end

    context 'when the client response is missing the data' do
      let(:client_response) { { success: true, usersUsage: nil } }

      it 'returns nil' do
        expect(user_usage.total_active_users).to be_nil
      end
    end
  end

  describe "#total_users_using_credits" do
    before do
      allow(subscription_usage_client).to receive(:get_users_usage_stats).and_return(client_response)
    end

    context 'when the client returns a successful response' do
      let(:client_response) { { success: true, usersUsage: { totalUsersUsingCredits: 3 } } }

      it 'returns the correct data' do
        expect(user_usage.total_users_using_credits).to eq(3)
      end
    end

    context 'when the client returns an unsuccessful response' do
      let(:client_response) { { success: false } }

      it 'returns nil' do
        expect(user_usage.total_users_using_credits).to be_nil
      end
    end

    context 'when the client response is missing the data' do
      let(:client_response) { { success: true, usersUsage: nil } }

      it 'returns nil' do
        expect(user_usage.total_users_using_credits).to be_nil
      end
    end
  end

  describe "#total_users_using_monthly_commitment" do
    before do
      allow(subscription_usage_client).to receive(:get_users_usage_stats).and_return(client_response)
    end

    context 'when the client returns a successful response' do
      let(:client_response) { { success: true, usersUsage: { totalUsersUsingMonthlyCommitment: 2 } } }

      it 'returns the correct data' do
        expect(user_usage.total_users_using_monthly_commitment).to eq(2)
      end
    end

    context 'when the client returns an unsuccessful response' do
      let(:client_response) { { success: false } }

      it 'returns nil' do
        expect(user_usage.total_users_using_monthly_commitment).to be_nil
      end
    end

    context 'when the client response is missing the data' do
      let(:client_response) { { success: true, usersUsage: nil } }

      it 'returns nil' do
        expect(user_usage.total_users_using_monthly_commitment).to be_nil
      end
    end
  end

  describe "#total_users_using_overage" do
    before do
      allow(subscription_usage_client).to receive(:get_users_usage_stats).and_return(client_response)
    end

    context 'when the client returns a successful response' do
      let(:client_response) { { success: true, usersUsage: { totalUsersUsingOverage: 1 } } }

      it 'returns the correct data' do
        expect(user_usage.total_users_using_overage).to eq(1)
      end
    end

    context 'when the client returns an unsuccessful response' do
      let(:client_response) { { success: false } }

      it 'returns nil' do
        expect(user_usage.total_users_using_overage).to be_nil
      end
    end

    context 'when the client response is missing the data' do
      let(:client_response) { { success: true, usersUsage: nil } }

      it 'returns nil' do
        expect(user_usage.total_users_using_overage).to be_nil
      end
    end
  end

  describe "#credits_used" do
    before do
      allow(subscription_usage_client).to receive(:get_users_usage_stats).and_return(client_response)
    end

    context 'when the client returns a successful response' do
      let(:client_response) { { success: true, usersUsage: { creditsUsed: 123.45 } } }

      it 'returns the correct data' do
        expect(user_usage.credits_used).to eq(123.45)
      end
    end

    context 'when the client returns an unsuccessful response' do
      let(:client_response) { { success: false } }

      it 'returns nil' do
        expect(user_usage.credits_used).to be_nil
      end
    end

    context 'when the client response is missing the data' do
      let(:client_response) { { success: true, usersUsage: nil } }

      it 'returns nil' do
        expect(user_usage.credits_used).to be_nil
      end
    end
  end

  describe "#users" do
    context 'when subscription_target is :namespace' do
      before do
        allow(subscription_usage).to receive_messages(
          subscription_target: :namespace,
          namespace: group
        )
      end

      it 'includes all users in the namespace hierarchy without the bot in the users field' do
        expect(user_usage.users).to match_array(full_group_user_list)
        expect(user_usage.users).not_to include(bot)
      end

      context 'when filtering by username' do
        it 'returns the user matching the username' do
          expect(user_usage.users(username: 'active_user')).to match_array([active_user])
        end

        it 'returns empty when username is a partial match' do
          expect(user_usage.users(username: 'user')).to be_empty
        end

        it 'returns the user from the subgroup' do
          expect(user_usage.users(username: subgroup_user.username)).to match_array([subgroup_user])
        end

        it 'returns empty when the user does not exist' do
          expect(user_usage.users(username: 'non-existent')).to be_empty
        end

        it 'returns empty when user is not a member of the group' do
          expect(user_usage.users(username: non_group_member_user.username)).to be_empty
        end

        it 'returns empty when user is a bot' do
          expect(user_usage.users(username: bot.username)).to be_empty
        end
      end

      context 'when searching users' do
        it 'returns users matching the partial name' do
          expect(user_usage.users(search_query: 'steve')).to match_array([active_user, subgroup_user])
        end

        it 'returns the user matching the partial username' do
          expect(user_usage.users(search_query: '_user')).to match_array([active_user, active_user2, service_user])
        end

        context 'when searching by email' do
          it 'returns the user matching the email' do
            expect(user_usage.users(search_query: 'firstuser@email.test')).to match_array([active_user])
          end

          it 'returns the user matching the partial email' do
            expect(user_usage.users(search_query: 'firstuser')).to match_array([active_user])
          end

          context 'when disable_partial_email_search feature is enabled', :saas_disable_partial_email_search do
            it 'does not return the user matching the partial email' do
              expect(user_usage.users(search_query: 'firstuser')).to be_empty
            end
          end
        end
      end

      context 'when namespace is nil' do
        before do
          allow(subscription_usage).to receive(:namespace).and_return(nil)
        end

        it 'raises an error when trying to get users' do
          expect { user_usage.users }.to raise_error(NoMethodError)
        end
      end

      context 'when namespace has no users' do
        let(:no_members_namespace) { create(:group) }

        before do
          allow(subscription_usage).to receive(:namespace).and_return(no_members_namespace)
        end

        it 'returns empty collection' do
          expect(user_usage.users).to be_empty
        end

        it 'returns empty collection when sorting is applied' do
          expect(user_usage.users(sort: :name_asc)).to be_empty
        end
      end

      context 'when sorting' do
        it 'returns users sorted by name ascending' do
          result = user_usage.users(sort: :name_asc)

          expect(result.to_a).to eq(result.sort_by { |u| u.name.downcase })
        end

        it 'returns users sorted by name descending' do
          result = user_usage.users(sort: :name_desc)

          expect(result.to_a).to eq(result.sort_by { |u| u.name.downcase }.reverse)
        end

        it 'returns unsorted users when sort is nil' do
          expect(user_usage.users(sort: nil)).to match_array(full_group_user_list)
        end

        it 'delegates to User.sort_by_attribute' do
          expect(User).to receive(:sort_by_attribute).with(:id_desc).and_call_original

          user_usage.users(sort: :id_desc)
        end
      end
    end

    context 'when subscription_target is :instance' do
      before do
        allow(subscription_usage).to receive(:subscription_target).and_return(:instance)
      end

      it 'includes all users except bots in the users field' do
        expect(user_usage.users).to match_array(full_group_user_list + [non_group_member_user])
        expect(user_usage.users).not_to include(bot)
      end

      context 'when filtering by username' do
        it 'returns the user matching the username' do
          expect(user_usage.users(username: 'active_user')).to match_array([active_user])
        end

        it 'returns empty when username is a partial match' do
          expect(user_usage.users(username: 'user')).to be_empty
        end

        it 'returns empty when the user does not exist' do
          expect(user_usage.users(username: 'non-existent')).to be_empty
        end

        it 'returns empty when user is a bot' do
          expect(user_usage.users(username: bot.username)).to be_empty
        end
      end

      context 'when searching users' do
        it 'returns users matching the partial name' do
          expect(user_usage.users(search_query: 'steve')).to match_array([active_user, subgroup_user])
        end

        it 'returns the user matching the partial username' do
          expect(user_usage.users(search_query: '_user')).to match_array([active_user, active_user2, service_user])
        end

        context 'when searching by email' do
          it 'returns the user matching the email' do
            expect(user_usage.users(search_query: 'firstuser@email.test')).to match_array([active_user])
          end

          it 'returns the user matching the partial email' do
            expect(user_usage.users(search_query: 'firstuser')).to match_array([active_user])
          end

          context 'when disable_partial_email_search feature is enabled', :saas_disable_partial_email_search do
            it 'does not return the user matching the partial email' do
              expect(user_usage.users(search_query: 'firstuser')).to be_empty
            end
          end
        end
      end

      context 'when sorting' do
        it 'returns users sorted by name ascending' do
          result = user_usage.users(sort: :name_asc)

          expect(result.to_a).to eq(result.sort_by { |u| u.name.downcase })
        end

        it 'returns users sorted by name descending' do
          result = user_usage.users(sort: :name_desc)

          expect(result.to_a).to eq(result.sort_by { |u| u.name.downcase }.reverse)
        end

        it 'returns unsorted users when sort is nil' do
          expect(user_usage.users(sort: nil)).to match_array(full_group_user_list + [non_group_member_user])
        end

        it 'delegates to User.sort_by_attribute' do
          expect(User).to receive(:sort_by_attribute).with(:id_desc).and_call_original

          user_usage.users(sort: :id_desc)
        end
      end
    end

    context 'when subscription_target is unknown' do
      before do
        allow(subscription_usage).to receive(:subscription_target).and_return(:unknown)
      end

      it 'returns nil for unknown subscription target' do
        expect(user_usage.users).to be_nil
      end
    end

    context 'when sorting by total_credits_used' do
      let(:consumers_response) do
        {
          nodes: [
            {
              userId: active_user.id,
              totalCredits: 100.12,
              creditsUsed: 50.34,
              monthlyCommitmentCreditsUsed: 30.56,
              monthlyWaiverCreditsUsed: 10.78,
              overageCreditsUsed: 10.91,
              paidTierTrialCreditsUsed: 3.45,
              totalCreditsUsed: 50.34
            },
            {
              userId: service_user.id,
              totalCredits: 80.0,
              creditsUsed: 40.0,
              monthlyCommitmentCreditsUsed: 20.0,
              monthlyWaiverCreditsUsed: 15.0,
              overageCreditsUsed: 5.0,
              paidTierTrialCreditsUsed: 2.0,
              totalCreditsUsed: 40.0
            },
            {
              userId: service_account.id,
              totalCredits: 0.0,
              creditsUsed: 0.0,
              monthlyCommitmentCreditsUsed: 0.0,
              monthlyWaiverCreditsUsed: 0.0,
              overageCreditsUsed: 0.0,
              paidTierTrialCreditsUsed: 0.0,
              totalCreditsUsed: 0.0,
              entityType: 'NON_HUMAN'
            }
          ],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: 'start',
            endCursor: 'end'
          }
        }
      end

      before do
        allow(subscription_usage_client).to receive(:get_consumers).and_return({ consumers: consumers_response })
      end

      context 'with sort :total_credits_used_desc' do
        it 'calls get_consumers with the correct sort' do
          expect(subscription_usage_client).to receive(:get_consumers).with(
            hash_including(sort: :total_credits_used_desc)
          ).and_return({ consumers: consumers_response })

          user_usage.users(sort: :total_credits_used_desc, first: 10)
        end

        it 'returns an ExternallyPaginatedArray with UserWithConsumption instances' do
          result = user_usage.users(sort: :total_credits_used_desc, first: 10)

          expect(result).to be_a(Gitlab::Graphql::ExternallyPaginatedArray)
          expect(result.map(&:id)).to eq([active_user.id, service_user.id])
          expect(result.first).to be_a(::GitlabSubscriptions::SubscriptionsUsage::UserWithConsumption)
          expect(result.first.usage).to have_attributes(
            total_credits: 100.12,
            credits_used: 50.34,
            monthly_commitment_credits_used: 30.56,
            monthly_waiver_credits_used: 10.78,
            overage_credits_used: 10.91,
            paid_tier_trial_credits_used: 3.45
          )
        end

        it 'includes pagination info' do
          result = user_usage.users(sort: :total_credits_used_desc, first: 10)

          expect(result.start_cursor).to eq('start')
          expect(result.end_cursor).to eq('end')
        end

        it 'filters out consumers without credit usage' do
          result = user_usage.users(sort: :total_credits_used_desc, first: 10)

          expect(result.map(&:id)).not_to include(service_account.id)
        end
      end

      context 'with sort :total_credits_used_asc' do
        it 'calls get_consumers with the correct sort' do
          expect(subscription_usage_client).to receive(:get_consumers).with(
            hash_including(sort: :total_credits_used_asc)
          ).and_return({ consumers: consumers_response })

          user_usage.users(sort: :total_credits_used_asc, first: 10)
        end
      end

      context 'when consumers response is empty' do
        let(:consumers_response) do
          {
            nodes: [],
            pageInfo: {}
          }
        end

        it 'returns an empty ExternallyPaginatedArray' do
          result = user_usage.users(sort: :total_credits_used_desc)

          expect(result).to be_a(Gitlab::Graphql::ExternallyPaginatedArray)
          expect(result.to_a).to be_empty
        end
      end

      context 'when a user is not found in database' do
        let(:consumers_response) do
          {
            nodes: [
              { userId: active_user.id, totalCredits: 100.0, creditsUsed: 50.0,
                monthlyCommitmentCreditsUsed: 30.0, monthlyWaiverCreditsUsed: 10.0, overageCreditsUsed: 10.0,
                paidTierTrialCreditsUsed: 3.0, totalCreditsUsed: 50.0 },
              { userId: -999, totalCredits: 80.0, creditsUsed: 40.0,
                monthlyCommitmentCreditsUsed: 20.0, monthlyWaiverCreditsUsed: 15.0, overageCreditsUsed: 5.0,
                paidTierTrialCreditsUsed: 2.0, totalCreditsUsed: 40.0 }
            ],
            pageInfo: { hasNextPage: false, hasPreviousPage: false, startCursor: 'start', endCursor: 'end' }
          }
        end

        it 'filters out missing users while maintaining order' do
          result = user_usage.users(sort: :total_credits_used_desc, first: 10)

          expect(result.map(&:id)).to eq([active_user.id])
        end
      end

      context 'with username filter' do
        before do
          allow(subscription_usage).to receive_messages(
            subscription_target: :namespace,
            namespace: group
          )
        end

        it 'does not use credits sorting when username is provided' do
          expect(subscription_usage_client).not_to receive(:get_consumers)

          user_usage.users(username: active_user.username, sort: :total_credits_used_desc)
        end
      end

      context 'with search_query filter' do
        it 'raises an ArgumentError when sorting by total_credits_used_desc' do
          expect do
            user_usage.users(search_query: 'steve', sort: :total_credits_used_desc, first: 10)
          end.to raise_error(Gitlab::Graphql::Errors::ArgumentError,
            '`searchQuery` not supported when sorting by total credits used')
        end

        it 'raises an ArgumentError when sorting by total_credits_used_asc' do
          expect do
            user_usage.users(search_query: 'steve', sort: :total_credits_used_asc, first: 10)
          end.to raise_error(Gitlab::Graphql::Errors::ArgumentError,
            '`searchQuery` not supported when sorting by total credits used')
        end

        it 'does not raise when search_query is blank' do
          expect(subscription_usage_client).to receive(:get_consumers).with(
            hash_including(sort: :total_credits_used_desc)
          ).and_return({ consumers: consumers_response })

          result = user_usage.users(search_query: '', sort: :total_credits_used_desc, first: 10)

          expect(result).to be_a(Gitlab::Graphql::ExternallyPaginatedArray)
        end
      end

      context 'when flow_types are provided' do
        it 'passes flow_types to get_consumers' do
          expect(subscription_usage_client).to receive(:get_consumers).with(
            hash_including(sort: :total_credits_used_desc, flow_types: %w[chat])
          ).and_return({ consumers: consumers_response })

          user_usage.users(sort: :total_credits_used_desc, first: 10, flow_types: %w[chat])
        end
      end
    end
  end

  describe "#declarative_policy_subject" do
    it 'sets declarative_policy_subject to SubscriptionUsage' do
      expect(user_usage.declarative_policy_subject).to eq(subscription_usage)
    end
  end
end
