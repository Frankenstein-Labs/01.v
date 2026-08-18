# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::GitlabSubscriptions::SubscriptionUsageResolver, feature_category: :consumables_cost_management do
  include GraphqlHelpers

  describe '#resolve' do
    context 'with a SaaS namespace subscription', :saas do
      let_it_be(:user) { create(:user) }
      let_it_be(:group) { create(:group) }
      let_it_be(:gitlab_subscription) do
        create(:gitlab_subscription, namespace: group, start_date: Date.new(2025, 10, 1))
      end

      before_all do
        group.add_owner(user)
      end

      before do
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      def resolve_usage(args = {}, ctx = { current_user: user })
        resolve(described_class, args: args, ctx: ctx)
      end

      describe 'date clamping' do
        let(:client_double) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }

        before do
          allow(Gitlab::SubscriptionPortal::SubscriptionUsageClient).to receive(:new).and_return(client_double)
          allow(client_double).to receive(:get_metadata).and_return({ success: true, subscriptionUsage: {} })
        end

        context 'when start_date is before the subscription start' do
          it 'clamps start_date to the subscription start date' do
            expect(Gitlab::SubscriptionPortal::SubscriptionUsageClient).to receive(:new).with(
              hash_including(
                start_date: '2025-10-01',
                end_date: '2025-10-31'
              )
            ).and_return(client_double)

            resolve_usage(
              namespace_path: group.full_path,
              start_date: Date.new(2025, 9, 1),
              end_date: Date.new(2025, 10, 31)
            )
          end
        end

        context 'when start_date is after the subscription start' do
          it 'keeps the requested start_date' do
            expect(Gitlab::SubscriptionPortal::SubscriptionUsageClient).to receive(:new).with(
              hash_including(
                start_date: '2025-10-15',
                end_date: '2025-10-31'
              )
            ).and_return(client_double)

            travel_to(Date.new(2025, 11, 1)) do
              resolve_usage(
                namespace_path: group.full_path,
                start_date: Date.new(2025, 10, 15),
                end_date: Date.new(2025, 10, 31)
              )
            end
          end
        end

        context 'when end_date is in the future' do
          it 'clamps end_date to today' do
            travel_to(Date.new(2025, 11, 1)) do
              expect(Gitlab::SubscriptionPortal::SubscriptionUsageClient).to receive(:new).with(
                hash_including(
                  end_date: '2025-11-01'
                )
              ).and_return(client_double)

              resolve_usage(
                namespace_path: group.full_path,
                start_date: Date.new(2025, 9, 1),
                end_date: Date.new(2025, 12, 1)
              )
            end
          end
        end

        context 'when namespace has no subscription' do
          let_it_be(:group_no_sub) { create(:group) }

          before_all do
            group_no_sub.add_owner(user)
          end

          it 'does not clamp start_date' do
            expect(Gitlab::SubscriptionPortal::SubscriptionUsageClient).to receive(:new).with(
              hash_including(
                start_date: '2025-09-01'
              )
            ).and_return(client_double)

            resolve_usage(
              namespace_path: group_no_sub.full_path,
              start_date: Date.new(2025, 9, 1),
              end_date: Date.new(2025, 10, 31)
            )
          end
        end
      end
    end

    context 'with a self-managed instance subscription' do
      let_it_be(:admin) { create(:admin) }
      let(:client_double) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }

      def resolve_usage(args = {})
        resolve(described_class, args: args, ctx: { current_user: admin })
      end

      before do
        allow(Gitlab::SubscriptionPortal::SubscriptionUsageClient).to receive(:new).and_return(client_double)
        allow(client_double).to receive(:get_metadata).and_return({ success: true, subscriptionUsage: {} })
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(admin, :read_subscription_usage).and_return(true)
      end

      context 'when the current license is a paid license' do
        let(:paid_license) { build(:license, plan: License::PREMIUM_PLAN) }

        before do
          allow(License).to receive(:billable_license).and_return(paid_license)
        end

        it 'builds the client with the paid license key' do
          expect(Gitlab::SubscriptionPortal::SubscriptionUsageClient).to receive(:new).with(
            hash_including(license_key: paid_license.data)
          ).and_return(client_double)

          resolve_usage
        end

        it 'clamps start_date to the paid license starts_at' do
          allow(paid_license).to receive(:starts_at).and_return(Date.new(2025, 6, 1))

          expect(Gitlab::SubscriptionPortal::SubscriptionUsageClient).to receive(:new).with(
            hash_including(start_date: '2025-06-01')
          ).and_return(client_double)

          resolve_usage(start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 6, 30))
        end
      end

      context 'when the instance has a credits add-on but no paid plan (add-on-only)' do
        let(:current_license) { build(:license) }

        before do
          allow(License).to receive(:billable_license).and_return(current_license)
        end

        it 'builds the client with the current license key' do
          expect(Gitlab::SubscriptionPortal::SubscriptionUsageClient).to receive(:new).with(
            hash_including(license_key: current_license.data)
          ).and_return(client_double)

          resolve_usage
        end
      end

      context 'when there is no billable license (free trial, no paid, no add-on)' do
        before do
          allow(License).to receive(:billable_license).and_return(nil)
        end

        it 'builds the client without a license key' do
          expect(Gitlab::SubscriptionPortal::SubscriptionUsageClient).to receive(:new).with(
            hash_not_including(:license_key)
          ).and_return(client_double)

          resolve_usage
        end
      end
    end
  end
end
