# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::AddOnTrialEligibleNamespacesFinder, feature_category: :subscription_management do
  describe '#execute', :saas do
    let_it_be(:user) { create :user }
    let_it_be(:namespace_with_free_plan) { create(:group_with_plan, plan: :free_plan) }

    context 'for duo' do
      subject(:execute) { described_class.new(user, add_on: :duo).execute }

      it { is_expected.to eq [] }

      context 'when the namespace is on a premium plan' do
        let_it_be(:namespace_with_paid_plan) { create(:group_with_plan, name: 'Zed', plan: :premium_plan) }
        let_it_be(:namespace_with_duo_pro) { create(:group_with_plan, plan: :premium_plan) }
        let_it_be(:namespace_with_duo_enterprise) { create(:group_with_plan, plan: :premium_plan) }
        let_it_be(:namespace_with_duo_core) { create(:group_with_plan, name: 'Delta', plan: :premium_plan) }
        let_it_be(:namespace_with_other_addon) { create(:group_with_plan, name: 'Alpha', plan: :premium_plan) }
        let_it_be(:namespace_with_middle_name) { create(:group_with_plan, name: 'Beta', plan: :premium_plan) }
        let_it_be(:namespace_with_ultimate_plan) { create(:group_with_plan, name: 'Gama', plan: :ultimate_plan) }

        before_all do
          create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: namespace_with_duo_pro)
          create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace_with_duo_enterprise)
          create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: namespace_with_duo_core)
          create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: namespace_with_other_addon)
        end

        context 'when user does not own groups' do
          it { is_expected.to eq [] }
        end

        context 'when user owns groups' do
          before_all do
            namespace_with_paid_plan.add_owner(user)
            namespace_with_duo_pro.add_owner(user)
            namespace_with_duo_enterprise.add_owner(user)
            namespace_with_duo_core.add_owner(user)
            namespace_with_free_plan.add_owner(user)
            namespace_with_other_addon.add_owner(user)
            namespace_with_middle_name.add_owner(user)
            namespace_with_ultimate_plan.add_owner(user)
          end

          it 'includes correct namespaces' do
            is_expected.to eq [
              namespace_with_other_addon,
              namespace_with_middle_name,
              namespace_with_duo_core,
              namespace_with_paid_plan
            ]
          end

          context 'when two addons' do
            before_all do
              create(:gitlab_subscription_add_on_purchase,
                namespace: namespace_with_duo_pro,
                add_on: namespace_with_duo_core.subscription_add_on_purchases.first.add_on)
            end

            it 'includes correct namespaces' do
              is_expected.to eq [
                namespace_with_other_addon,
                namespace_with_middle_name,
                namespace_with_duo_core,
                namespace_with_paid_plan
              ]
            end
          end
        end
      end
    end

    context 'for duo_enterprise' do
      let_it_be(:namespace_with_paid_plan) { create(:group_with_plan, name: 'Zed', plan: :ultimate_plan) }
      let_it_be(:namespace_with_duo) { create(:group_with_plan, plan: :ultimate_plan) }
      let_it_be(:namespace_with_duo_core) { create(:group_with_plan, name: 'Delta', plan: :ultimate_plan) }
      let_it_be(:namespace_with_other_addon) { create(:group_with_plan, name: 'Alpha', plan: :ultimate_plan) }
      let_it_be(:namespace_with_premium_plan) { create(:group_with_plan, name: 'Gama', plan: :premium_plan) }
      let_it_be(:namespace_with_middle_name) { create(:group_with_plan, name: 'Beta', plan: :ultimate_plan) }

      before_all do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace_with_duo)
        create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: namespace_with_duo_core)
        create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: namespace_with_other_addon)
      end

      subject(:execute) { described_class.new(user, add_on: :duo_enterprise).execute }

      context 'when the add-on does not exist in the system' do
        it { is_expected.to eq [] }
      end

      context 'when the add-on exists in the system' do
        context 'when user does not own groups' do
          it { is_expected.to eq [] }
        end

        context 'when user owns groups' do
          before_all do
            namespace_with_paid_plan.add_owner(user)
            namespace_with_duo.add_owner(user)
            namespace_with_duo_core.add_owner(user)
            namespace_with_premium_plan.add_owner(user)
            namespace_with_free_plan.add_owner(user)
            namespace_with_other_addon.add_owner(user)
            namespace_with_middle_name.add_owner(user)
          end

          it 'includes correct namespaces' do
            is_expected.to eq [
              namespace_with_other_addon,
              namespace_with_middle_name,
              namespace_with_duo_core,
              namespace_with_paid_plan
            ]
          end

          context 'when two addons' do
            before_all do
              create(:gitlab_subscription_add_on_purchase,
                namespace: namespace_with_duo,
                add_on: namespace_with_duo_core.subscription_add_on_purchases.first.add_on)
            end

            it 'includes correct namespaces' do
              is_expected.to eq [
                namespace_with_other_addon,
                namespace_with_middle_name,
                namespace_with_duo_core,
                namespace_with_paid_plan
              ]
            end
          end
        end
      end
    end

    context 'with invalid add_on' do
      subject(:execute) { described_class.new(user, add_on: :invalid_add_on).execute }

      it 'raises an error' do
        expect { execute }.to raise_error(ArgumentError)
      end
    end
  end
end
