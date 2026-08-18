# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionUsage, feature_category: :consumables_cost_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:users) { create_list(:user, 3) }
  let_it_be(:group) { create(:group, developers: users.first(2)) }
  let(:subscription_usage_client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }

  describe '#start_date' do
    subject(:start_date) { subscription_usage.start_date }

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) { { success: true, subscriptionUsage: { startDate: "2025-10-01" } } }

        it 'returns the start date' do
          expect(start_date).to be("2025-10-01")
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(start_date).to be_nil
        end
      end

      context 'when the client response is missing startDate' do
        let(:client_response) { { success: true, subscriptionUsage: { startDate: nil } } }

        it 'returns nil' do
          expect(start_date).to be_nil
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) { { success: true, subscriptionUsage: { startDate: "2025-10-01" } } }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns the start date' do
        expect(start_date).to be("2025-10-01")
      end
    end
  end

  describe '#end_date' do
    subject(:end_date) { subscription_usage.end_date }

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) { { success: true, subscriptionUsage: { endDate: "2025-10-31" } } }

        it 'returns the end date' do
          expect(end_date).to be("2025-10-31")
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(end_date).to be_nil
        end
      end

      context 'when the client response is missing endDate' do
        let(:client_response) { { success: true, subscriptionUsage: { endDate: nil } } }

        it 'returns nil' do
          expect(end_date).to be_nil
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) { { success: true, subscriptionUsage: { endDate: "2025-10-31" } } }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns the end date' do
        expect(end_date).to be("2025-10-31")
      end
    end
  end

  describe '#purchase_credits_path' do
    let(:client_response) { { success: true, subscriptionUsage: { enabled: true } } }
    let(:subgroup) { create(:group, parent: group) }

    subject(:purchase_credits_path) { subscription_usage.purchase_credits_path }

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    context 'when gitlab_com_subscriptions enabled', :saas_gitlab_com_subscriptions do
      shared_examples 'returns expected path' do
        context 'when the client returns enabled' do
          it 'returns the correct path' do
            expect(purchase_credits_path).to eq(
              "/subscriptions/purchases/gitlab?deployment_type=gitlab_com" \
                "&gl_namespace_id=#{group.id}&plan_type=gitlab_credits"
            )
          end
        end

        context 'when the client returns not enabled' do
          let(:client_response) { { success: false } }

          it 'returns nil' do
            expect(purchase_credits_path).to be_nil
          end
        end

        context 'when the client returns enabled=false' do
          let(:client_response) { { success: true, subscriptionUsage: { enabled: false } } }

          it 'returns nil' do
            expect(purchase_credits_path).to be_nil
          end
        end
      end

      context 'when namespace is a subgroup' do
        let(:subscription_usage) do
          described_class.new(
            subscription_target: :namespace,
            subscription_usage_client: subscription_usage_client,
            namespace: subgroup
          )
        end

        include_examples 'returns expected path'
      end

      context 'when namespace is a root' do
        let(:subscription_usage) do
          described_class.new(
            subscription_target: :namespace,
            subscription_usage_client: subscription_usage_client,
            namespace: group
          )
        end

        include_examples 'returns expected path'
      end

      context 'when namespace does not return root_ancestor' do
        before do
          allow(group).to receive(:root_ancestor).and_return(nil)
        end

        let(:subscription_usage) do
          described_class.new(
            subscription_target: :namespace,
            subscription_usage_client: subscription_usage_client,
            namespace: group
          )
        end

        it 'returns nil' do
          expect(purchase_credits_path).to eq(
            "/subscriptions/purchases/gitlab?deployment_type=gitlab_com&plan_type=gitlab_credits"
          )
        end
      end

      context 'when namespace does not exist' do
        let(:group) { nil }
        let(:subscription_usage) do
          described_class.new(
            subscription_target: :namespace,
            subscription_usage_client: subscription_usage_client,
            namespace: group
          )
        end

        it 'returns nil' do
          expect(purchase_credits_path).to be_nil
        end
      end

      context 'when namespace is not provided' do
        let(:subscription_usage) do
          described_class.new(
            subscription_target: :namespace,
            subscription_usage_client: subscription_usage_client
          )
        end

        it 'returns nil' do
          expect(purchase_credits_path).to be_nil
        end
      end
    end

    context 'when gitlab_com_subscriptions not enabled' do
      let!(:subscription_name) { 'A-S00000001' }
      let(:gitlab_license) { build(:gitlab_license, restrictions: { subscription_name: subscription_name }) }
      let(:license) { create(:license, data: gitlab_license.export) }
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      before do
        allow(License).to receive(:billable_license).and_return(license)
      end

      context 'when the client returns enabled' do
        it 'returns the correct path' do
          expect(purchase_credits_path).to eq(
            "/subscriptions/purchases/gitlab?deployment_type=self_managed&" \
              "plan_type=gitlab_credits&subscription_name=A-S00000001"
          )
        end
      end

      context 'when the client returns not enabled' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(purchase_credits_path).to be_nil
        end
      end

      context 'when the client returns enabled=false' do
        let(:client_response) { { success: true, subscriptionUsage: { enabled: false } } }

        it 'returns nil' do
          expect(purchase_credits_path).to be_nil
        end
      end

      context 'when the current license is a trial with an active paid license' do
        let(:trial_gitlab_license) do
          build(:gitlab_license, restrictions: { subscription_name: 'A-S-TRIAL-001' })
        end

        let(:trial_license) { build(:license, :ultimate_trial, data: trial_gitlab_license.export) }

        before do
          allow(License).to receive_messages(current: trial_license, billable_license: license)
        end

        it 'returns the path using the paid subscription name, not the trial subscription name' do
          expect(purchase_credits_path).to eq(
            "/subscriptions/purchases/gitlab?deployment_type=self_managed&" \
              "plan_type=gitlab_credits&subscription_name=A-S00000001"
          )
        end
      end

      context 'when the instance has a credits add-on but no paid plan' do
        let(:add_on_gitlab_license) do
          build(:gitlab_license, restrictions: { subscription_name: 'A-S00000001' })
        end

        let(:add_on_license) { create(:license, data: add_on_gitlab_license.export) }

        before do
          allow(License).to receive(:billable_license).and_return(add_on_license)
        end

        it 'returns the path using the current license subscription name' do
          expect(purchase_credits_path).to eq(
            "/subscriptions/purchases/gitlab?deployment_type=self_managed&" \
              "plan_type=gitlab_credits&subscription_name=A-S00000001"
          )
        end
      end

      context 'when billable_license is nil (free trial, no paid, no add-on)' do
        before do
          allow(License).to receive(:billable_license).and_return(nil)
        end

        it 'returns nil' do
          expect(purchase_credits_path).to be_nil
        end
      end

      context 'when license does not have a subscription' do
        let(:gitlab_license) { build(:gitlab_license, restrictions: { trial: false }) }

        it 'returns nil' do
          expect(purchase_credits_path).to be_nil
        end
      end

      context 'when license subscription_name is nil' do
        let(:gitlab_license) { build(:gitlab_license, restrictions: { subscription_name: nil }) }

        it 'returns nil' do
          expect(purchase_credits_path).to be_nil
        end
      end
    end
  end

  describe '#credits_used' do
    subject(:credits_used) { subscription_usage.credits_used }

    before do
      allow(subscription_usage_client).to receive(:get_subscription_usage).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) do
          {
            success: true,
            subscriptionUsage: {
              creditsUsed: 287.45
            }
          }
        end

        it 'returns the credits used value' do
          expect(credits_used).to eq(287.45)
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(credits_used).to be_nil
        end
      end

      context 'when the client response is missing creditsUsed data' do
        let(:client_response) do
          {
            success: true,
            subscriptionUsage: nil
          }
        end

        it 'returns nil' do
          expect(credits_used).to be_nil
        end
      end

      context 'when flow_types are provided' do
        let(:subscription_usage) do
          described_class.new(
            subscription_target: :namespace,
            subscription_usage_client: subscription_usage_client,
            namespace: group,
            flow_types: %w[chat]
          )
        end

        let(:client_response) { { success: true, subscriptionUsage: { creditsUsed: 123.45 } } }

        it 'passes flow_types to the client' do
          credits_used

          expect(subscription_usage_client)
            .to have_received(:get_subscription_usage)
                  .with(hash_including(flow_types: %w[chat]))
        end

        it 'returns the filtered value' do
          expect(credits_used).to eq(123.45)
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) do
        {
          success: true,
          subscriptionUsage: {
            creditsUsed: 543.21
          }
        }
      end

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns the credits used value' do
        expect(credits_used).to eq(543.21)
      end
    end
  end

  describe '#daily_usage' do
    subject(:daily_usage) { subscription_usage.daily_usage }

    before do
      allow(subscription_usage_client).to receive_messages(
        get_subscription_usage: client_response,
        start_date: '2025-10-01',
        end_date: '2025-10-31'
      )
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) do
          {
            success: true,
            subscriptionUsage: {
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 287.45 }]
            }
          }
        end

        it 'returns daily usage structs with correct data' do
          expect(daily_usage).to contain_exactly(
            have_attributes(
              date: '2025-10-01',
              credits_used: 287.45,
              declarative_policy_subject: subscription_usage
            )
          )
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(daily_usage).to be_nil
        end
      end

      context 'when the client response is missing dailyUsage data' do
        let(:client_response) do
          {
            success: true,
            subscriptionUsage: nil
          }
        end

        it 'returns an empty array' do
          expect(daily_usage).to eq([])
        end
      end

      context 'when the client response has null dailyUsage' do
        let(:client_response) do
          {
            success: true,
            subscriptionUsage: { dailyUsage: nil }
          }
        end

        it 'returns an empty array' do
          expect(daily_usage).to eq([])
        end
      end

      context 'when called with arguments' do
        let(:client_response) { { success: true, subscriptionUsage: {} } }

        it 'passes sort and limit to the client' do
          subscription_usage.daily_usage(sort: :credits_used_desc, limit: 5)

          expect(subscription_usage_client).to have_received(:get_subscription_usage)
            .with(hash_including(sort: :credits_used_desc, limit: 5))
        end

        it 'raises an argument error when limit exceeds the number of days in the date range' do
          expect { subscription_usage.daily_usage(limit: 32) }
            .to raise_error(
              Gitlab::Graphql::Errors::ArgumentError,
              'limit cannot exceed the number of days in the date range (31)'
            )
        end

        it 'does not raise an error when limit equals the number of days in the date range' do
          expect { subscription_usage.daily_usage(limit: 31) }.not_to raise_error
        end

        it 'does not raise an error when limit is less than the number of days in the date range' do
          expect { subscription_usage.daily_usage(limit: 1) }.not_to raise_error
        end
      end

      context 'when limit is not provided and date range is shorter than default limit' do
        before do
          allow(subscription_usage_client).to receive_messages(
            get_subscription_usage: client_response,
            start_date: '2025-10-01',
            end_date: '2025-10-07'
          )
        end

        let(:client_response) { { success: true, subscriptionUsage: {} } }

        it 'does not raise an error' do
          expect { subscription_usage.daily_usage }.not_to raise_error
        end

        it 'caps the limit to the number of days in the range' do
          subscription_usage.daily_usage

          expect(subscription_usage_client).to have_received(:get_subscription_usage)
                                                 .with(hash_including(sort: :date_asc, limit: 7))
        end
      end

      context 'when flow_types are provided' do
        let(:subscription_usage) do
          described_class.new(
            subscription_target: :namespace,
            subscription_usage_client: subscription_usage_client,
            namespace: group,
            flow_types: %w[chat]
          )
        end

        let(:client_response) do
          {
            success: true,
            subscriptionUsage: {
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 100 }]
            }
          }
        end

        it 'passes flow_types to the client' do
          subscription_usage.daily_usage

          expect(subscription_usage_client)
            .to have_received(:get_subscription_usage)
                  .with(hash_including(flow_types: %w[chat]))
        end
      end

      context 'when max_days_in_range is zero' do
        let(:client_response) { { success: true, subscriptionUsage: {} } }

        before do
          allow(subscription_usage_client).to receive_messages(
            start_date: '2025-10-31',
            end_date: '2025-10-01'
          )
        end

        it 'returns an empty array without calling CDot' do
          expect(subscription_usage_client).not_to receive(:get_subscription_usage)
          expect(daily_usage).to eq([])
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) do
        {
          success: true,
          subscriptionUsage: {
            dailyUsage: [{ date: '2025-10-02', creditsUsed: 543.21 }]
          }
        }
      end

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns the daily usage value' do
        expect(daily_usage).to contain_exactly(
          have_attributes(
            date: '2025-10-02',
            credits_used: 543.21,
            declarative_policy_subject: subscription_usage
          )
        )
      end
    end
  end

  describe '#daily_average' do
    subject(:daily_average) { subscription_usage.daily_average }

    before do
      allow(subscription_usage_client).to receive(:get_subscription_usage).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response with dailyAverage' do
        let(:client_response) do
          {
            success: true,
            subscriptionUsage: {
              dailyAverage: 150.0
            }
          }
        end

        it 'returns the daily average from the response' do
          expect(daily_average).to eq(150.0)
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(daily_average).to be_nil
        end
      end

      context 'when the client response is missing subscription usage data' do
        let(:client_response) do
          {
            success: true,
            subscriptionUsage: nil
          }
        end

        it 'returns nil' do
          expect(daily_average).to be_nil
        end
      end

      context 'when flow_types are provided' do
        let(:subscription_usage) do
          described_class.new(
            subscription_target: :namespace,
            subscription_usage_client: subscription_usage_client,
            namespace: group,
            flow_types: %w[chat]
          )
        end

        let(:client_response) { { success: true, subscriptionUsage: { dailyAverage: 10.0 } } }

        it 'passes flow_types to the client' do
          subscription_usage.daily_average

          expect(subscription_usage_client)
            .to have_received(:get_subscription_usage)
                  .with(hash_including(flow_types: %w[chat]))
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) do
        {
          success: true,
          subscriptionUsage: {
            dailyAverage: 225.0
          }
        }
      end

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns the daily average from the response' do
        expect(daily_average).to eq(225.0)
      end
    end
  end

  describe '#enabled?' do
    where(:cdot_enabled_value, :return_value) do
      true  | true
      false | false
      nil   | false
    end

    with_them do
      before do
        allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
      end

      context "when subscription portal returns #{params[:cdot_enabled_value]} for enabled" do
        let(:subscription_usage) do
          described_class.new(
            subscription_target: :instance,
            subscription_usage_client: subscription_usage_client
          )
        end

        let(:client_response) do
          { success: true, subscriptionUsage: { enabled: cdot_enabled_value } }
        end

        it "returns #{params[:return_value]} for enabled?" do
          expect(subscription_usage.enabled?).to be return_value
        end
      end
    end
  end

  describe '#outdated_client?' do
    where(:outdated_client) { [true, false] }

    with_them do
      before do
        allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
      end

      context "when subscription portal returns #{params[:outdated_client]} for isOutdatedClient" do
        let(:subscription_usage) do
          described_class.new(
            subscription_target: :instance,
            subscription_usage_client: subscription_usage_client
          )
        end

        let(:client_response) do
          { success: true, subscriptionUsage: { isOutdatedClient: outdated_client } }
        end

        it "returns #{params[:outdated_client]} for outdated_client?" do
          expect(subscription_usage.outdated_client?).to be outdated_client
        end
      end
    end
  end

  describe '#last_event_transaction_at' do
    subject(:last_event_transaction_at) { subscription_usage.last_event_transaction_at }

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) do
          { success: true, subscriptionUsage: { lastEventTransactionAt: "2025-10-01T16:19:59Z" } }
        end

        it 'returns the last updated time' do
          expect(last_event_transaction_at).to be("2025-10-01T16:19:59Z")
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(last_event_transaction_at).to be_nil
        end
      end

      context 'when the client response is missing lastEventTransactionAt' do
        let(:client_response) { { success: true, subscriptionUsage: { lastEventTransactionAt: nil } } }

        it 'returns nil' do
          expect(last_event_transaction_at).to be_nil
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) { { success: true, subscriptionUsage: { lastEventTransactionAt: "2025-10-01T16:19:59Z" } } }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns the last updated time' do
        expect(last_event_transaction_at).to be("2025-10-01T16:19:59Z")
      end
    end
  end

  describe '#monthly_waiver' do
    subject(:monthly_waiver) { subscription_usage.monthly_waiver }

    before do
      allow(subscription_usage_client).to receive(:get_monthly_waiver).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) do
          {
            success: true,
            monthlyWaiver: {
              totalCredits: 1000.55,
              creditsUsed: 25.32,
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 25.32 }]
            }
          }
        end

        it 'returns a MonthlyWaiver struct with correct data' do
          expect(monthly_waiver).to be_a(GitlabSubscriptions::SubscriptionUsage::MonthlyWaiver)
          expect(monthly_waiver).to have_attributes(
            total_credits: 1000.55,
            credits_used: 25.32,
            daily_usage: be_an(Array),
            declarative_policy_subject: subscription_usage
          )

          expect(monthly_waiver.daily_usage.size).to eq(1)
          expect(monthly_waiver.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
          expect(monthly_waiver.daily_usage.first).to have_attributes(
            date: '2025-10-01',
            credits_used: 25.32,
            declarative_policy_subject: subscription_usage
          )
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(monthly_waiver).to be_nil
        end
      end

      context 'when the client response is missing monthlyWaiver data' do
        let(:client_response) do
          {
            success: true,
            monthlyWaiver: nil
          }
        end

        it 'returns a MonthlyWaiver struct with no values' do
          expect(monthly_waiver).to be_a(GitlabSubscriptions::SubscriptionUsage::MonthlyWaiver)
          expect(monthly_waiver).to have_attributes(
            total_credits: nil,
            credits_used: nil,
            daily_usage: [],
            declarative_policy_subject: subscription_usage
          )
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) do
        {
          success: true,
          monthlyWaiver: {
            totalCredits: 2000.12,
            creditsUsed: 123.99,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 123.99 }]
          }
        }
      end

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns a MonthlyWaiver struct with correct data' do
        expect(monthly_waiver).to be_a(GitlabSubscriptions::SubscriptionUsage::MonthlyWaiver)
        expect(monthly_waiver).to have_attributes(
          total_credits: 2000.12,
          credits_used: 123.99,
          daily_usage: be_an(Array),
          declarative_policy_subject: subscription_usage
        )

        expect(monthly_waiver.daily_usage.size).to eq(1)
        expect(monthly_waiver.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
        expect(monthly_waiver.daily_usage.first).to have_attributes(
          date: '2025-10-01',
          credits_used: 123.99,
          declarative_policy_subject: subscription_usage
        )
      end
    end
  end

  describe '#monthly_commitment' do
    subject(:monthly_commitment) { subscription_usage.monthly_commitment }

    before do
      allow(subscription_usage_client).to receive(:get_monthly_commitment).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) do
          {
            success: true,
            monthlyCommitment: {
              totalCredits: 1000,
              creditsUsed: 750,
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 750 }]
            }
          }
        end

        it 'returns a MonthlyCommitment struct with correct data' do
          expect(monthly_commitment).to be_a(GitlabSubscriptions::SubscriptionUsage::MonthlyCommitment)
          expect(monthly_commitment).to have_attributes(
            total_credits: 1000,
            credits_used: 750,
            daily_usage: be_an(Array),
            declarative_policy_subject: subscription_usage
          )

          expect(monthly_commitment.daily_usage.size).to eq(1)
          expect(monthly_commitment.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
          expect(monthly_commitment.daily_usage.first).to have_attributes(
            date: '2025-10-01',
            credits_used: 750,
            declarative_policy_subject: subscription_usage
          )
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(monthly_commitment).to be_nil
        end
      end

      context 'when the client response is missing monthlyCommitment data' do
        let(:client_response) do
          {
            success: true,
            monthlyCommitment: nil
          }
        end

        it 'returns a MonthlyCommitment struct with no values' do
          expect(monthly_commitment).to be_a(GitlabSubscriptions::SubscriptionUsage::MonthlyCommitment)
          expect(monthly_commitment).to have_attributes(
            total_credits: nil,
            credits_used: nil,
            daily_usage: [],
            declarative_policy_subject: subscription_usage
          )
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) do
        {
          success: true,
          monthlyCommitment: {
            totalCredits: 2000,
            creditsUsed: 1500,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 1500 }]
          }
        }
      end

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns a MonthlyCommitment struct with correct data' do
        expect(monthly_commitment).to be_a(GitlabSubscriptions::SubscriptionUsage::MonthlyCommitment)
        expect(monthly_commitment).to have_attributes(
          total_credits: 2000,
          credits_used: 1500,
          daily_usage: be_an(Array),
          declarative_policy_subject: subscription_usage
        )

        expect(monthly_commitment.daily_usage.size).to eq(1)
        expect(monthly_commitment.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
        expect(monthly_commitment.daily_usage.first).to have_attributes(
          date: '2025-10-01',
          credits_used: 1500,
          declarative_policy_subject: subscription_usage
        )
      end
    end
  end

  describe '#overage' do
    subject(:overage) { subscription_usage.overage }

    before do
      allow(subscription_usage_client).to receive(:get_overage).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) do
          {
            success: true,
            overage: {
              isAllowed: true,
              creditsUsed: 750,
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 750 }]
            }
          }
        end

        it 'returns an Overage struct with correct data' do
          expect(overage).to be_a(GitlabSubscriptions::SubscriptionUsage::Overage)
          expect(overage).to have_attributes(
            is_allowed: true,
            credits_used: 750,
            daily_usage: be_an(Array),
            declarative_policy_subject: subscription_usage
          )

          expect(overage.daily_usage.size).to eq(1)
          expect(overage.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
          expect(overage.daily_usage.first).to have_attributes(
            date: '2025-10-01',
            credits_used: 750,
            declarative_policy_subject: subscription_usage
          )
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(overage).to be_nil
        end
      end

      context 'when the client response is missing overage data' do
        let(:client_response) do
          {
            success: true,
            overage: nil
          }
        end

        it 'returns an Overage struct with no values' do
          expect(overage).to be_a(GitlabSubscriptions::SubscriptionUsage::Overage)
          expect(overage).to have_attributes(
            is_allowed: nil,
            credits_used: nil,
            daily_usage: [],
            declarative_policy_subject: subscription_usage
          )
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) do
        {
          success: true,
          overage: {
            isAllowed: true,
            creditsUsed: 1500,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 1500 }]
          }
        }
      end

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns an Overage struct with correct data' do
        expect(overage).to be_a(GitlabSubscriptions::SubscriptionUsage::Overage)
        expect(overage).to have_attributes(
          is_allowed: true,
          credits_used: 1500,
          daily_usage: be_an(Array),
          declarative_policy_subject: subscription_usage
        )

        expect(overage.daily_usage.size).to eq(1)
        expect(overage.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
        expect(overage.daily_usage.first).to have_attributes(
          date: '2025-10-01',
          credits_used: 1500,
          declarative_policy_subject: subscription_usage
        )
      end
    end
  end

  describe '#products' do
    subject(:products) { subscription_usage.products }

    before do
      allow(subscription_usage_client).to receive(:get_products).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) do
          {
            success: true,
            products: [
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
                flowTypes: []
              }
            ]
          }
        end

        it 'returns an array of Product structs with correct data' do
          expect(products).to be_an(Array)
          expect(products.size).to eq(2)

          expect(products.first).to be_a(GitlabSubscriptions::SubscriptionUsage::Product)
          expect(products.first).to have_attributes(
            id: 'duo_agent_platform',
            title: 'Duo Agent Platform',
            credits_used: 150.5,
            declarative_policy_subject: subscription_usage
          )

          expect(products.first.flow_types).to be_an(Array)
          expect(products.first.flow_types.size).to eq(2)
          expect(products.first.flow_types.first).to be_a(GitlabSubscriptions::SubscriptionUsage::ProductFlowType)
          expect(products.first.flow_types.first).to have_attributes(
            id: 'code_suggestions',
            title: 'Code Suggestions',
            declarative_policy_subject: subscription_usage
          )

          expect(products.last).to have_attributes(
            id: 'other_product',
            title: 'Other Product',
            credits_used: 75.25,
            flow_types: [],
            declarative_policy_subject: subscription_usage
          )
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(products).to be_nil
        end
      end

      context 'when the client response has nil products' do
        let(:client_response) do
          {
            success: true,
            products: nil
          }
        end

        it 'returns an empty array' do
          expect(products).to eq([])
        end
      end

      context 'when a product has nil flow_types' do
        let(:client_response) do
          {
            success: true,
            products: [{ id: 'duo_agent_platform', title: 'Duo Agent Platform', creditsUsed: 10.0, flowTypes: nil }]
          }
        end

        it 'returns an empty array for flow_types' do
          expect(products.first.flow_types).to eq([])
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) do
        {
          success: true,
          products: [
            {
              id: 'duo_agent_platform',
              title: 'Duo Agent Platform',
              creditsUsed: 200.0,
              flowTypes: [
                { id: 'code_suggestions', title: 'Code Suggestions' }
              ]
            }
          ]
        }
      end

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns an array of Product structs with correct data' do
        expect(products).to be_an(Array)
        expect(products.size).to eq(1)

        expect(products.first).to be_a(GitlabSubscriptions::SubscriptionUsage::Product)
        expect(products.first).to have_attributes(
          id: 'duo_agent_platform',
          title: 'Duo Agent Platform',
          credits_used: 200.0,
          declarative_policy_subject: subscription_usage
        )

        expect(products.first.flow_types.size).to eq(1)
        expect(products.first.flow_types.first).to have_attributes(
          id: 'code_suggestions',
          title: 'Code Suggestions',
          declarative_policy_subject: subscription_usage
        )
      end
    end
  end

  describe '#users_usage' do
    let(:subscription_usage) do
      described_class.new(
        subscription_target: :instance,
        subscription_usage_client: subscription_usage_client
      )
    end

    it 'initiates a UserUsage object with the correct params' do
      expect(GitlabSubscriptions::SubscriptionsUsage::UserUsage).to receive(:new)
        .with(subscription_usage: subscription_usage)

      subscription_usage.users_usage
    end
  end

  describe '#budget_caps' do
    context 'when instance scope' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      it 'returns a BudgetCaps instance' do
        result = subscription_usage.budget_caps

        expect(result).to be_a(GitlabSubscriptions::SubscriptionsUsage::BudgetCaps)
      end

      it 'passes self as subscription_usage' do
        expect(GitlabSubscriptions::SubscriptionsUsage::BudgetCaps).to receive(:new)
          .with(subscription_usage: subscription_usage)

        subscription_usage.budget_caps
      end
    end

    context 'when namespace scope' do
      let_it_be(:namespace) { create(:group) }

      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: namespace
        )
      end

      it 'returns a BudgetCaps instance' do
        expect(subscription_usage.budget_caps).to be_a(
          GitlabSubscriptions::SubscriptionsUsage::BudgetCaps
        )
      end
    end
  end

  describe '#overage_terms_accepted' do
    let(:subscription_usage) do
      described_class.new(
        subscription_target: :instance,
        subscription_usage_client: subscription_usage_client
      )
    end

    let(:client_response) do
      { success: true, subscriptionUsage: { overageTermsAccepted: value } }
    end

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    where(:value) { [true, false] }

    with_them do
      it 'returns the raw value from metadata' do
        expect(subscription_usage.overage_terms_accepted).to eq(value)
      end
    end
  end

  describe '#can_accept_overage_terms' do
    where(:cdot_value, :return_value) do
      true  | true
      false | false
      nil   | false
    end

    with_them do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:client_response) do
        { success: true, subscriptionUsage: { canAcceptOverageTerms: cdot_value } }
      end

      before do
        allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
      end

      it "returns #{params[:return_value]} when CDot returns #{params[:cdot_value].inspect}" do
        expect(subscription_usage.can_accept_overage_terms).to be(return_value)
      end
    end
  end

  describe '#dap_promo_enabled' do
    let(:subscription_usage) do
      described_class.new(
        subscription_target: :instance,
        subscription_usage_client: subscription_usage_client
      )
    end

    let(:client_response) do
      { success: true, subscriptionUsage: { dapPromoEnabled: value } }
    end

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    where(:value) { [true, false] }

    with_them do
      it 'returns the raw value from metadata' do
        expect(subscription_usage.dap_promo_enabled).to eq(value)
      end
    end
  end

  describe '#paid_tier_trial' do
    let(:subscription_usage) do
      described_class.new(
        subscription_target: :instance,
        subscription_usage_client: subscription_usage_client
      )
    end

    context 'when get_paid_tier_trial returns successful response with daily usage' do
      where(:is_active_value, :daily_usage_data) do
        true  | [{ date: '2025-10-01', creditsUsed: 10.5 }, { date: '2025-10-02', creditsUsed: 15.25 }]
        false | []
      end

      with_them do
        let(:paid_tier_trial_response) do
          {
            success: true,
            paidTierTrial: {
              isActive: is_active_value,
              dailyUsage: daily_usage_data
            }
          }
        end

        before do
          allow(subscription_usage_client).to receive(:get_paid_tier_trial).and_return(paid_tier_trial_response)
        end

        it "returns a PaidTierTrial struct with is_active=#{params[:is_active_value]} and daily usage data" do
          paid_tier_trial = subscription_usage.paid_tier_trial

          expect(paid_tier_trial).to be_a(GitlabSubscriptions::SubscriptionUsage::PaidTierTrial)
          expect(paid_tier_trial).to have_attributes(
            is_active: is_active_value,
            declarative_policy_subject: subscription_usage
          )
          expect(paid_tier_trial.daily_usage).to be_an(Array)
          expect(paid_tier_trial.daily_usage.size).to eq(daily_usage_data.size)
          expect(paid_tier_trial.daily_usage).to match_array(
            daily_usage_data.map do |usage|
              have_attributes(
                date: usage[:date],
                credits_used: usage[:creditsUsed],
                declarative_policy_subject: subscription_usage
              )
            end
          )
        end
      end
    end

    context 'when get_paid_tier_trial returns unsuccessful response' do
      let(:paid_tier_trial_response) do
        { success: false }
      end

      before do
        allow(subscription_usage_client).to receive(:get_paid_tier_trial).and_return(paid_tier_trial_response)
      end

      it 'returns a PaidTierTrial struct with is_active=false and empty daily_usage' do
        paid_tier_trial = subscription_usage.paid_tier_trial

        expect(paid_tier_trial).to be_a(GitlabSubscriptions::SubscriptionUsage::PaidTierTrial)
        expect(paid_tier_trial).to have_attributes(
          is_active: false,
          daily_usage: [],
          declarative_policy_subject: subscription_usage
        )
      end
    end

    context 'when get_paid_tier_trial returns empty daily usage' do
      let(:paid_tier_trial_response) do
        {
          success: true,
          paidTierTrial: {
            isActive: true,
            dailyUsage: []
          }
        }
      end

      before do
        allow(subscription_usage_client).to receive(:get_paid_tier_trial).and_return(paid_tier_trial_response)
      end

      it 'returns a PaidTierTrial struct with is_active=true and empty daily_usage' do
        paid_tier_trial = subscription_usage.paid_tier_trial

        expect(paid_tier_trial).to be_a(GitlabSubscriptions::SubscriptionUsage::PaidTierTrial)
        expect(paid_tier_trial).to have_attributes(
          is_active: true,
          daily_usage: [],
          declarative_policy_subject: subscription_usage
        )
      end
    end

    context 'when get_paid_tier_trial returns nil daily usage' do
      let(:paid_tier_trial_response) do
        {
          success: true,
          paidTierTrial: {
            isActive: false,
            dailyUsage: nil
          }
        }
      end

      before do
        allow(subscription_usage_client).to receive(:get_paid_tier_trial).and_return(paid_tier_trial_response)
      end

      it 'returns a PaidTierTrial struct with is_active=false and nil daily_usage' do
        paid_tier_trial = subscription_usage.paid_tier_trial

        expect(paid_tier_trial).to be_a(GitlabSubscriptions::SubscriptionUsage::PaidTierTrial)
        expect(paid_tier_trial).to have_attributes(
          is_active: false,
          daily_usage: [],
          declarative_policy_subject: subscription_usage
        )
      end
    end
  end

  describe '#usage_dashboard_path' do
    let(:subscription_usage) do
      described_class.new(
        subscription_target: :instance,
        subscription_usage_client: subscription_usage_client
      )
    end

    let(:client_response) do
      { success: true, subscriptionUsage: { usageDashboardPath: value } }
    end

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    where(:value) { [true, false] }

    with_them do
      it 'returns the raw value from metadata' do
        expect(subscription_usage.usage_dashboard_path).to eq(value)
      end
    end
  end

  describe '#subscription_portal_usage_dashboard_url' do
    let(:subscription_usage) do
      described_class.new(
        subscription_target: :instance,
        subscription_usage_client: subscription_usage_client
      )
    end

    subject(:url) { subscription_usage.subscription_portal_usage_dashboard_url }

    context 'when subscription cannot accept overage terms' do
      before do
        allow(subscription_usage).to receive(:can_accept_overage_terms).and_return(false)
      end

      it 'returns nil' do
        expect(url).to be_nil
      end
    end

    context 'when subscription can accept overage terms but path is blank' do
      before do
        allow(subscription_usage).to receive_messages(can_accept_overage_terms: true, usage_dashboard_path: nil)
      end

      it 'returns nil' do
        expect(url).to be_nil
      end
    end

    context 'when subscription can accept overage terms and path is present' do
      before do
        allow(subscription_usage).to receive_messages(can_accept_overage_terms: true,
          usage_dashboard_path: '/subscriptions/A-S00012345/usage')
      end

      it 'returns the full Subscription Portal URL' do
        expect(url).to eq(
          "#{::Gitlab::SubscriptionPortal.default_production_customer_portal_url}/subscriptions/A-S00012345/usage"
        )
      end
    end
  end
end
