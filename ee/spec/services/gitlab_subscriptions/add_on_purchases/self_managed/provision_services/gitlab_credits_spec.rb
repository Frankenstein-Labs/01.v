# frozen_string_literal: true

require 'spec_helper'
RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::GitlabCredits,
  :freeze_time, feature_category: :'add-on_provisioning' do
  describe '#execute' do
    include_context 'with provision services common setup'

    let_it_be(:add_on_gitlab_credits) { create(:gitlab_subscription_add_on, :gitlab_credits) }

    describe 'delegations' do
      subject { provision_service }

      it_behaves_like 'delegates add_on params to license_add_on'
    end

    context 'without GitLab Credits' do
      let(:add_ons) { [] }

      it 'does not create a GitLab Credits add-on purchase' do
        expect { provision_service.execute }.not_to change { GitlabSubscriptions::AddOnPurchase.count }
      end
    end

    context 'with GitLab Credits' do
      let(:add_ons) { %i[gitlab_credits] }

      it 'creates a new GitLab Credits add-on purchase' do
        expect do
          provision_service.execute
        end.to change { GitlabSubscriptions::AddOnPurchase.count }.from(0).to(1)

        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
          subscription_add_on_id: add_on_gitlab_credits.id,
          quantity: quantity,
          started_at: started_at,
          expires_on: started_at + 1.year,
          purchase_xid: purchase_xid,
          trial: trial
        )
      end
    end

    context 'with existing GitLab Credits' do
      let(:add_ons) { %i[gitlab_credits] }

      context 'with seat count increase' do
        let(:quantity) { 2 }
        let!(:existing_gitlab_credits) do
          create(
            :gitlab_subscription_add_on_purchase,
            add_on: add_on_gitlab_credits,
            quantity: 1,
            namespace: namespace
          )
        end

        it 'updates quantity of existing add-on purchase' do
          expect { provision_service.execute }.not_to change { GitlabSubscriptions::AddOnPurchase.count }
          expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
            subscription_add_on_id: add_on_gitlab_credits.id,
            quantity: quantity,
            started_at: started_at,
            expires_on: started_at + 1.year,
            purchase_xid: purchase_xid,
            trial: trial
          )
        end
      end

      context 'when expired' do
        let!(:existing_gitlab_credits) do
          create(
            :gitlab_subscription_add_on_purchase,
            add_on: add_on_gitlab_credits,
            quantity: quantity,
            started_at: 2.years.ago,
            expires_on: 1.year.ago,
            namespace: namespace
          )
        end

        it 'updates existing add-on purchase' do
          expect do
            provision_service.execute
          end.not_to change { GitlabSubscriptions::AddOnPurchase.count }

          expect(existing_gitlab_credits.reload.started_at).to eq(started_at)
          expect(existing_gitlab_credits.expires_on).to eq(started_at + 1.year)
        end
      end

      context 'with an additional add-on purchase' do
        let(:add_ons) { %i[gitlab_credits duo_amazon_q] }
        let!(:existing_gitlab_credits) do
          create(
            :gitlab_subscription_add_on_purchase,
            add_on: add_on_gitlab_credits,
            quantity: quantity,
            namespace: nil
          )
        end

        it 'does not affect the GitLab Credits purchase' do
          expect { provision_service.execute }.not_to change { GitlabSubscriptions::AddOnPurchase.count }
          expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
            subscription_add_on_id: add_on_gitlab_credits.id,
            quantity: quantity,
            started_at: started_at,
            expires_on: started_at + 1.year,
            purchase_xid: purchase_xid,
            trial: trial
          )
        end
      end
    end

    context 'with other existing add-ons' do
      let_it_be(:add_on_duo_core) { create(:gitlab_subscription_add_on, :duo_core) }
      let_it_be(:add_on_duo_pro) { create(:gitlab_subscription_add_on, :duo_pro) }
      let_it_be(:add_on_self_hosted_dap) { create(:gitlab_subscription_add_on, :self_hosted_dap) }

      let(:existing_add_on_attrs) do
        {
          quantity: 3,
          started_at: 1.day.ago.to_date,
          expires_on: (1.day.ago + 1.year).to_date,
          namespace: namespace,
          trial: trial
        }
      end

      let!(:existing_duo_pro) do
        create(:gitlab_subscription_add_on_purchase,
          existing_add_on_attrs.merge(
            add_on: add_on_duo_pro,
            purchase_xid: '987654321'
          )
        )
      end

      let!(:existing_duo_core) do
        create(:gitlab_subscription_add_on_purchase,
          existing_add_on_attrs.merge(
            add_on: add_on_duo_core,
            purchase_xid: '987612345'
          )
        )
      end

      let!(:existing_self_hosted_dap) do
        create(:gitlab_subscription_add_on_purchase,
          existing_add_on_attrs.merge(
            add_on: add_on_self_hosted_dap,
            purchase_xid: '981276345'
          )
        )
      end

      context 'with additional purchase of GitLab Credits' do
        let(:add_ons) { %i[duo_core duo_pro self_hosted_dap gitlab_credits] }

        it 'does not affect the existing add-on purchases' do
          expect do
            provision_service.execute
          end.to change { GitlabSubscriptions::AddOnPurchase.count }.from(3).to(4)

          expect(existing_duo_pro.reload).to have_attributes(
            existing_add_on_attrs.merge(subscription_add_on_id: add_on_duo_pro.id, purchase_xid: '987654321')
          )
          expect(existing_duo_core.reload).to have_attributes(
            existing_add_on_attrs.merge(subscription_add_on_id: add_on_duo_core.id, purchase_xid: '987612345')
          )
          expect(existing_self_hosted_dap.reload).to have_attributes(
            existing_add_on_attrs.merge(subscription_add_on_id: add_on_self_hosted_dap.id, purchase_xid: '981276345')
          )
        end
      end
    end
  end
end
