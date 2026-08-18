# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::Base,
  feature_category: :plan_provisioning do
  describe '#execute' do
    let_it_be(:subscription_name) { 'A-S00000001' }

    let!(:current_license) do
      create_current_license(
        cloud_licensing_enabled: true,
        restrictions: {
          subscription_name: subscription_name
        }
      )
    end

    context 'without add_on_purchase implemented' do
      subject(:klass) { provision_service_class }

      let(:provision_service_class) do
        Class.new(described_class) do
          define_method :quantity do
            0
          end
        end
      end

      it { expect { klass.new.execute }.to raise_error described_class::MethodNotImplementedError }
    end

    context 'with implemented class', :aggregate_failures do
      subject(:result) { provision_services_base_class.new.execute }

      let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
      let_it_be(:add_on_purchase) { nil }
      let_it_be(:organization) { create(:organization) }
      let_it_be(:namespace) { nil }
      let_it_be(:quantity) { 1 }
      let_it_be(:starts_at) { Date.current }
      let_it_be(:purchase_xid) { 'C-12345678' }
      let_it_be(:trial) { false }

      let(:provision_services_base_class) do
        current_add_on = add_on
        current_add_on_purchase = add_on_purchase
        current_quantity = quantity
        current_starts_at = starts_at
        current_purchase_xid = purchase_xid
        current_trial = trial

        Class.new(described_class) do
          define_method :add_on_purchase do
            current_add_on_purchase
          end

          define_method :add_on do
            current_add_on
          end

          define_method :quantity do
            current_quantity
          end

          define_method :starts_at do
            current_starts_at
          end

          define_method :expires_on do
            current_starts_at + 1.year
          end

          define_method :purchase_xid do
            current_purchase_xid
          end

          define_method :trial? do
            current_trial
          end
        end
      end

      context 'without a current license', :without_license do
        let!(:current_license) { nil }

        it_behaves_like 'provision service expires add-on purchase'
      end

      context 'when current license is a legacy license' do
        let!(:current_license) do
          create_current_license(
            cloud_licensing_enabled: false,
            offline_cloud_licensing_enabled: false
          )
        end

        it_behaves_like 'provision service expires add-on purchase'
      end

      context 'when current license is an offline license' do
        let!(:current_license) do
          create_current_license(
            cloud_licensing_enabled: true,
            offline_cloud_licensing_enabled: true,
            restrictions: {
              subscription_name: subscription_name
            }
          )
        end

        it_behaves_like 'provision service creates add-on purchase'
      end

      context 'when current license does not contain a code suggestions add-on purchase' do
        let_it_be(:quantity) { 0 }

        it_behaves_like 'provision service expires add-on purchase'
      end

      context 'when add-on purchase exists' do
        let(:expires_on) { Date.current + 3.months }
        let!(:add_on_purchase) do
          create(
            :gitlab_subscription_add_on_purchase,
            namespace: namespace,
            add_on: add_on,
            started_at: current_license.starts_at,
            expires_on: expires_on,
            purchase_xid: 'A-S00000001'
          )
        end

        context 'when the update fails' do
          it_behaves_like 'provision service handles error', GitlabSubscriptions::AddOnPurchases::UpdateService
        end

        context 'when existing add-on purchase is expired' do
          let(:expires_on) { Date.current - 3.months }

          it_behaves_like 'provision service updates the existing add-on purchase'
        end

        it_behaves_like 'provision service updates the existing add-on purchase'
      end

      context 'when the creation fails' do
        it_behaves_like 'provision service handles error', GitlabSubscriptions::AddOnPurchases::CreateService
      end

      it_behaves_like 'provision service creates add-on purchase'
    end
  end
end
