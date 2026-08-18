# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::DuoExclusive,
  :aggregate_failures, feature_category: :'add-on_provisioning' do
  describe '#execute', :aggregate_failures do
    include_context 'with provision services common setup'

    let_it_be(:add_on_duo_core) { create(:gitlab_subscription_add_on, :duo_core) }
    let_it_be(:add_on_duo_pro) { create(:gitlab_subscription_add_on, :duo_pro) }
    let_it_be(:add_on_duo_enterprise) { create(:gitlab_subscription_add_on, :duo_enterprise) }
    let_it_be(:add_on_duo_amazon_q) { create(:gitlab_subscription_add_on, :duo_amazon_q) }

    describe 'delegations' do
      subject { provision_service }

      it_behaves_like 'delegates add_on params to license_add_on'
    end

    context 'without Duo' do
      let!(:current_license) do
        create_current_license(
          cloud_licensing_enabled: true,
          restrictions: {
            add_on_products: {},
            subscription_name: 'A-S00000001'
          }
        )
      end

      it 'does not create a Duo Pro add-on purchase' do
        expect { provision_service.execute }.not_to change { GitlabSubscriptions::AddOnPurchase.count }
      end
    end

    shared_examples 'provision duo add-on purchase' do
      context 'with a trial' do
        let(:trial) { true }

        it 'creates a new Duo Pro add-on purchase' do
          expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)

          expect(GitlabSubscriptions::AddOnPurchase.count).to eq(1)
          expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
            subscription_add_on_id: expected_add_on.id,
            quantity: 1,
            started_at: started_at,
            expires_on: started_at + 1.year,
            purchase_xid: purchase_xid,
            trial: true
          )
        end
      end

      it 'creates a new Duo Pro add-on purchase' do
        expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)

        expect(GitlabSubscriptions::AddOnPurchase.count).to eq(1)
        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
          subscription_add_on_id: expected_add_on.id,
          quantity: 1,
          started_at: started_at,
          expires_on: started_at + 1.year,
          purchase_xid: purchase_xid,
          trial: false
        )
      end
    end

    shared_examples 'seat increase provision' do
      it 'updates quantity of existing add-on purchase' do
        expect { provision_service.execute }.not_to change { GitlabSubscriptions::AddOnPurchase.count }

        expect(GitlabSubscriptions::AddOnPurchase.count).to eq(1)
        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
          subscription_add_on_id: add_on.id,
          quantity: quantity,
          started_at: started_at,
          expires_on: started_at + 1.year,
          purchase_xid: purchase_xid,
          trial: trial
        )
      end
    end

    shared_examples 'seat increase provision for trials and non-trials' do
      let!(:add_on_purchase_duo_enterprise) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on,
          quantity: 1,
          namespace: namespace
        )
      end

      it_behaves_like 'seat increase provision'

      context 'with a trial' do
        let(:trial) { true }

        it_behaves_like 'seat increase provision'
      end
    end

    shared_examples 'update existing Duo add-on purchase' do
      let!(:add_on_purchase_duo_enterprise) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: initial_add_on,
          quantity: 1,
          namespace: namespace
        )
      end

      it 'updates the add-on' do
        expect { provision_service.execute }.not_to change { GitlabSubscriptions::AddOnPurchase.count }

        expect(GitlabSubscriptions::AddOnPurchase.count).to eq(1)
        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
          subscription_add_on_id: expected_add_on.id,
          quantity: 1,
          started_at: started_at,
          expires_on: started_at + 1.year,
          purchase_xid: purchase_xid,
          trial: false
        )
      end
    end

    context 'with Duo Pro' do
      let(:add_ons) { %i[duo_pro] }
      let(:expected_add_on) { add_on_duo_pro }

      it_behaves_like 'provision duo add-on purchase'
    end

    context 'with existing Duo Pro and seat count increase' do
      let(:add_on) { add_on_duo_pro }
      let(:add_ons) { %i[duo_pro] }
      let(:quantity) { 2 }

      it_behaves_like 'seat increase provision for trials and non-trials'
    end

    context 'with existing Duo Pro and additional purchase of Duo Enterprise' do
      let(:add_ons) { %i[duo_pro duo_enterprise] }
      let(:initial_add_on) { add_on_duo_pro }
      let(:expected_add_on) { add_on_duo_enterprise }

      it_behaves_like 'update existing Duo add-on purchase'
    end

    context 'with Duo Enterprise' do
      let(:add_ons) { %i[duo_enterprise] }
      let(:expected_add_on) { add_on_duo_enterprise }

      it_behaves_like 'provision duo add-on purchase'
    end

    context 'with existing Duo Enterprise and seat count increase' do
      let(:add_on) { add_on_duo_enterprise }
      let(:add_ons) { %i[duo_enterprise] }
      let(:quantity) { 2 }

      it_behaves_like 'seat increase provision for trials and non-trials'
    end

    context 'with existing Duo Enterprise and downgrade to Duo Pro' do
      let(:add_ons) { %i[duo_pro] }
      let(:initial_add_on) { add_on_duo_enterprise }
      let(:expected_add_on) { add_on_duo_pro }

      it_behaves_like 'update existing Duo add-on purchase'
    end

    context 'with Duo with Amazon Q' do
      let(:add_ons) { %i[duo_amazon_q] }
      let(:expected_add_on) { add_on_duo_amazon_q }

      it_behaves_like 'provision duo add-on purchase'
    end

    context 'with existing Duo Enterprise and additional purchase of Duo with Amazon Q' do
      let(:add_ons) { %i[duo_enterprise duo_amazon_q] }
      let(:initial_add_on) { add_on_duo_enterprise }
      let(:expected_add_on) { add_on_duo_amazon_q }

      it_behaves_like 'update existing Duo add-on purchase'
    end

    context 'with existing Duo Amazon Q and downgrade to Duo Enterprise' do
      let(:add_ons) { %i[duo_enterprise] }
      let(:initial_add_on) { add_on_duo_amazon_q }
      let(:expected_add_on) { add_on_duo_enterprise }

      it_behaves_like 'update existing Duo add-on purchase'
    end
  end
end
