# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::SecretsManager,
  :freeze_time, feature_category: :'add-on_provisioning' do
  describe '#execute' do
    include_context 'with provision services common setup'

    let_it_be(:add_on_secrets_manager) { create(:gitlab_subscription_add_on, :secrets_manager) }
    let_it_be(:add_on_self_hosted_dap) { create(:gitlab_subscription_add_on, :self_hosted_dap) }

    describe 'delegations' do
      subject { provision_service }

      it_behaves_like 'delegates add_on params to license_add_on'
    end

    context 'without Secrets Manager' do
      let(:add_ons) { [] }

      it 'does not create a Secrets Manager add-on purchase' do
        expect { provision_service.execute }.not_to change { GitlabSubscriptions::AddOnPurchase.count }
      end
    end

    context 'with Secrets Manager' do
      let(:add_ons) { %i[secrets_manager] }

      it 'creates a new Secrets Manager add-on purchase' do
        expect do
          provision_service.execute
        end.to change { GitlabSubscriptions::AddOnPurchase.count }.from(0).to(1)

        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
          subscription_add_on_id: add_on_secrets_manager.id,
          quantity: quantity,
          started_at: started_at,
          expires_on: started_at + 1.year,
          purchase_xid: purchase_xid,
          trial: trial
        )
      end
    end

    context 'with existing Secrets Manager' do
      let(:add_ons) { %i[secrets_manager] }

      context 'when expired' do
        let!(:existing_secrets_manager) do
          create(
            :gitlab_subscription_add_on_purchase,
            add_on: add_on_secrets_manager,
            quantity: quantity,
            started_at: 2.years.ago,
            expires_on: 1.year.ago,
            namespace: namespace
          )
        end

        it 'updates existing add-on purchase', :aggregate_failures do
          expect do
            provision_service.execute
          end.not_to change { GitlabSubscriptions::AddOnPurchase.count }

          expect(existing_secrets_manager.reload.started_at).to eq(started_at)
          expect(existing_secrets_manager.expires_on).to eq(started_at + 1.year)
        end
      end

      context 'with an additional add-on purchase' do
        let(:add_ons) { %i[secrets_manager self_hosted_dap] }

        let!(:existing_secrets_manager) do
          create(
            :gitlab_subscription_add_on_purchase,
            add_on: add_on_secrets_manager,
            quantity: quantity,
            namespace: nil
          )
        end

        it 'does not affect the Secrets Manager purchase', :aggregate_failures do
          expect { provision_service.execute }.not_to change { GitlabSubscriptions::AddOnPurchase.count }

          expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
            subscription_add_on_id: add_on_secrets_manager.id,
            quantity: quantity,
            started_at: started_at,
            expires_on: started_at + 1.year,
            purchase_xid: purchase_xid,
            trial: trial
          )
        end
      end
    end

    context 'with existing Self-Hosted DAP' do
      let(:existing_add_on_attrs) do
        {
          quantity: 1,
          started_at: 1.day.ago.to_date,
          expires_on: (1.day.ago + 1.year).to_date,
          namespace: namespace,
          trial: trial
        }
      end

      let!(:existing_self_hosted_dap) do
        create(:gitlab_subscription_add_on_purchase,
          existing_add_on_attrs.merge(
            add_on: add_on_self_hosted_dap,
            purchase_xid: '987654321'
          )
        )
      end

      context 'with additional purchase of Secrets Manager' do
        let(:add_ons) { %i[self_hosted_dap secrets_manager] }

        it 'does not affect the existing add-on purchase', :aggregate_failures do
          expect do
            provision_service.execute
          end.to change { GitlabSubscriptions::AddOnPurchase.count }.from(1).to(2)

          existing_self_hosted_dap.reload

          expect(existing_self_hosted_dap).to have_attributes(
            existing_add_on_attrs.merge(subscription_add_on_id: add_on_self_hosted_dap.id, purchase_xid: '987654321')
          )
        end
      end
    end
  end
end
