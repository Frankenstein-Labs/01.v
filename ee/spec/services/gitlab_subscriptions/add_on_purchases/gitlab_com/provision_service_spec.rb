# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::GitlabCom::ProvisionService,
  :aggregate_failures, feature_category: :plan_provisioning do
  describe '#execute' do
    subject(:execute_service) { described_class.new(namespace, add_on_products).execute }

    let_it_be_with_reload(:namespace) { create(:group) }
    let_it_be(:started_at) { Date.current.to_s }
    let_it_be(:expires_on) { 1.year.from_now.to_date.to_s }
    let_it_be(:yesterday) { Time.zone.yesterday }
    let_it_be(:error) { ServiceResponse.error(message: 'Something went wrong') }
    let_it_be(:success) { ServiceResponse.success(message: 'Everything is good') }

    let(:add_on_name) { :duo_enterprise }
    let(:purchase_xid) { 'S-A00000001' }
    let(:quantity) { 1 }
    let(:trial) { false }

    let(:add_on_product) do
      {
        'started_on' => started_at,
        'expires_on' => expires_on,
        'purchase_xid' => purchase_xid,
        'quantity' => quantity,
        'trial' => trial
      }
    end

    let(:expected_attributes) do
      {
        started_at: started_at.to_date,
        expires_on: expires_on.to_date,
        namespace: namespace,
        purchase_xid: purchase_xid,
        quantity: quantity,
        trial: trial
      }
    end

    let(:add_on_products) { { add_on_name => [add_on_product] } }

    it 'creates add-on' do
      expect { execute_service }.to change { GitlabSubscriptions::AddOn.count }.by(1)

      expect(GitlabSubscriptions::AddOn.first).to be_duo_enterprise
    end

    it 'creates add-on purchase' do
      expect { execute_service }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)

      expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(expected_attributes)
    end

    it 'returns successful service response' do
      expect(execute_service).to be_success
      expect(execute_service.message).to be_nil
      expect(execute_service.payload).to eq({ add_on_purchases: GitlabSubscriptions::AddOnPurchase.all })
    end

    it 'enqueues refresh user assignments worker' do
      expect(GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker)
        .to receive(:perform_async).with(namespace.id)

      execute_service
    end

    context 'with empty products' do
      let(:add_on_products) { { add_on_name => [] } }

      it 'does nothing' do
        expect { execute_service }
          .to not_change { GitlabSubscriptions::AddOn.count }
          .and not_change { GitlabSubscriptions::AddOnPurchase.count }

        expect(execute_service).to be_success
        expect(execute_service.message).to be_nil
        expect(execute_service.payload).to eq({ add_on_purchases: [] })
      end
    end

    context 'with multiple products' do
      let(:add_on_products) { { add_on_name => [add_on_product, add_on_product] } }

      it 'considers only one' do
        expect { execute_service }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)
        expect(execute_service.payload).to eq({ add_on_purchases: [GitlabSubscriptions::AddOnPurchase.first] })
      end
    end

    context 'with existing add-on' do
      it 'creates no add-on' do
        create(:gitlab_subscription_add_on, :duo_enterprise)

        expect { execute_service }.not_to change { GitlabSubscriptions::AddOn.count }
      end
    end

    context 'with existing add-on purchase' do
      before do
        create(
          :gitlab_subscription_add_on_purchase,
          :duo_enterprise,
          started_at: 1.year.ago.to_date.to_s,
          expires_on: Date.current.to_s,
          namespace: namespace,
          purchase_xid: '123',
          quantity: 2,
          trial: true
        )
      end

      it 'creates no add-on purchase' do
        expect { execute_service }.not_to change { GitlabSubscriptions::AddOnPurchase.count }
      end

      it 'updates existing add-on purchase' do
        execute_service

        expect(GitlabSubscriptions::AddOnPurchase.count).to eq 1
        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(expected_attributes)
      end
    end

    context 'with existing add-on purchase for another namespace' do
      before do
        create(
          :gitlab_subscription_add_on_purchase,
          :duo_enterprise,
          namespace: create(:group)
        )
      end

      it 'creates add-on purchase' do
        expect { execute_service }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)
      end
    end

    context 'with Duo Enterprise and existing Duo Pro add-on purchase' do
      before do
        create(
          :gitlab_subscription_add_on_purchase,
          :duo_pro,
          started_at: 1.year.ago.to_date.to_s,
          expires_on: Date.current.to_s,
          namespace: namespace,
          purchase_xid: '123',
          quantity: 2,
          trial: true
        )
      end

      it 'reuses and updates existing Duo add-on purchase' do
        expect { execute_service }.not_to change { GitlabSubscriptions::AddOnPurchase.count }
        expect(GitlabSubscriptions::AddOnPurchase.count).to eq 1
        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
          add_on: have_attributes(name: 'duo_enterprise'),
          started_at: started_at.to_date,
          expires_on: expires_on.to_date,
          namespace: namespace,
          purchase_xid: purchase_xid,
          quantity: quantity,
          trial: trial
        )
      end
    end

    context 'with Duo Pro' do
      let(:add_on_name) { :duo_pro }

      it 'creates add-on by using the add-on mapping' do
        expect { execute_service }.to change { GitlabSubscriptions::AddOn.count }.by(1)

        expect(GitlabSubscriptions::AddOn.first).to be_code_suggestions
      end

      context 'with existing Duo Enterprise add-on purchase' do
        before do
          create(
            :gitlab_subscription_add_on_purchase,
            :duo_enterprise,
            started_at: 1.year.ago.to_date.to_s,
            expires_on: Date.current.to_s,
            namespace: namespace,
            purchase_xid: '123',
            trial: true
          )
        end

        it 'reuses and updates existing Duo add-on purchase' do
          expect { execute_service }.not_to change { GitlabSubscriptions::AddOnPurchase.count }
          expect(GitlabSubscriptions::AddOnPurchase.count).to eq 1
          expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
            add_on: have_attributes(name: 'code_suggestions'),
            started_at: started_at.to_date,
            expires_on: expires_on.to_date,
            namespace: namespace,
            purchase_xid: purchase_xid,
            quantity: quantity,
            trial: trial
          )
        end
      end
    end

    context 'with update service error' do
      before do
        create(
          :gitlab_subscription_add_on_purchase,
          :duo_enterprise,
          started_at: 1.year.ago.to_date.to_s,
          expires_on: Date.current.to_s,
          namespace: namespace,
          purchase_xid: '123',
          trial: true
        )

        allow_next_instance_of(GitlabSubscriptions::AddOnPurchases::GitlabCom::UpdateService) do |instance|
          allow(instance).to receive(:execute).and_return error
        end
      end

      it 'returns error service response' do
        expect(execute_service).to be_error
        expect(execute_service.message).to eq 'Something went wrong'
      end

      it 'does not enqueue refresh user assignments worker' do
        expect(GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker)
          .not_to receive(:perform_async).with(namespace.id)

        execute_service
      end
    end

    context 'with create service error' do
      before do
        allow_next_instance_of(GitlabSubscriptions::AddOnPurchases::CreateService) do |instance|
          allow(instance).to receive(:execute).and_return error
        end
      end

      it 'provisions no add-ons purchase' do
        expect { execute_service }.not_to change { GitlabSubscriptions::AddOnPurchase.count }
      end

      it 'returns error service response' do
        expect(execute_service).to be_error
        expect(execute_service.message).to eq 'Something went wrong'
      end

      it 'does not enqueue refresh user assignments worker' do
        expect(GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker)
          .not_to receive(:perform_async).with(namespace.id)

        execute_service
      end
    end

    context 'with multiple add-ons' do
      let(:add_on_products) do
        {
          'duo_pro' => [{
            'started_on' => started_at,
            'expires_on' => expires_on,
            'purchase_xid' => purchase_xid,
            'quantity' => quantity,
            'trial' => trial
          }],
          'product_analytics' => [{
            'started_on' => started_at,
            'expires_on' => expires_on,
            'purchase_xid' => purchase_xid,
            'quantity' => quantity,
            'trial' => trial
          }]
        }
      end

      it 'creates multiple add-ons' do
        expect { execute_service }.to change { GitlabSubscriptions::AddOn.count }.by(2)
      end

      it 'provisions multiple add-ons purchases' do
        expect { execute_service }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(2)
      end

      context 'with one provision is failing' do
        before do
          add_on_products['duo_pro'].first['quantity'] = 0
        end

        it 'saves provisionable add-on purchases' do
          expect { execute_service }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)
        end

        it 'creates add-ons' do
          expect { execute_service }.to change { GitlabSubscriptions::AddOn.count }.by(1)
        end

        it 'returns success service response' do
          expect(execute_service).to be_success
          expect(execute_service.message).to eq 'Nothing to provision or de-provision'

          add_on_purchases = execute_service.payload[:add_on_purchases]
          expect(add_on_purchases.count).to eq 1

          expect(add_on_purchases.first).to be_persisted
          expect(add_on_purchases.first).to have_attributes(
            expected_attributes.merge(add_on: have_attributes(name: 'product_analytics'))
          )
        end

        it 'enqueues refresh user assignments worker' do
          expect(GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker)
            .to receive(:perform_async).with(namespace.id)

          execute_service
        end
      end

      context 'with Duo Pro and Enterprise' do
        let(:add_on_products) do
          {
            'duo_pro' => [add_on_product],
            'duo_enterprise' => [add_on_product]
          }
        end

        it 'consolidate Duo add-ons' do
          expect { execute_service }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)
        end

        it 'provisions only Duo Enterprise' do
          execute_service

          expect(GitlabSubscriptions::AddOnPurchase.count).to eq 1
          expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
            expected_attributes.merge(add_on: have_attributes(name: 'duo_enterprise'))
          )
        end
      end

      context 'with Duo Core and another Duo add-on' do
        let(:add_on_products) do
          {
            'duo_core' => [add_on_product],
            'duo_pro' => [add_on_product]
          }
        end

        it 'creates multiple add-ons' do
          expect { execute_service }.to change { GitlabSubscriptions::AddOn.count }.by(2)
        end

        it 'provisions multiple add-ons purchases' do
          expect { execute_service }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(2)
        end

        it 'provisions both add-on purchases' do
          execute_service

          expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
            expected_attributes.merge(add_on: have_attributes(name: 'duo_core'))
          )

          expect(GitlabSubscriptions::AddOnPurchase.second).to have_attributes(
            expected_attributes.merge(add_on: have_attributes(name: 'code_suggestions'))
          )
        end

        context 'when Duo Core params new_subscription flag is true' do
          let(:add_on_products) do
            {
              'duo_core' => [add_on_product.merge(new_subscription: true)],
              'duo_pro' => [add_on_product]
            }
          end

          it_behaves_like 'enables DuoCore automatically only if customer has not chosen DuoCore setting for namespace'
        end

        context 'when Duo Core params new_subscription flag is false' do
          let(:add_on_products) do
            {
              'duo_core' => [add_on_product.merge(new_subscription: false)],
              'duo_pro' => [add_on_product]
            }
          end

          it_behaves_like 'does not change namespace Duo Core features setting'
        end
      end

      context 'with Duo Pro and empty Duo Enterprise' do
        let(:add_on_products) do
          {
            'duo_pro' => [add_on_product],
            'duo_enterprise' => []
          }
        end

        it 'provisions Duo Pro' do
          expect { execute_service }.to change { GitlabSubscriptions::AddOn.count }.by(1)

          expect(GitlabSubscriptions::AddOnPurchase.first.add_on).to be_code_suggestions
        end
      end

      context 'with Duo Core to deprovision' do
        let!(:add_on_purchase) do
          create(
            :gitlab_subscription_add_on_purchase,
            :duo_core,
            started_at: started_at,
            expires_on: expires_on,
            namespace: namespace,
            purchase_xid: purchase_xid,
            quantity: quantity,
            trial: trial
          )
        end

        let(:add_on_products) do
          {
            'duo_core' => [{
              'started_on' => yesterday,
              'expires_on' => yesterday,
              'purchase_xid' => nil,
              'quantity' => nil,
              'trial' => false
            }]
          }
        end

        it 'deprovisions add-on purchase' do
          execute_service

          expect(add_on_purchase.reload).to have_attributes(
            add_on: be_duo_core,
            started_at: yesterday,
            expires_on: yesterday,
            purchase_xid: 'S-A00000001',
            quantity: 1
          )
        end
      end

      context 'with Duo Pro to provision and Duo Enterprise to deprovision' do
        let(:add_on_products) do
          {
            'duo_pro' => [add_on_product],
            'duo_enterprise' => [{
              'started_on' => yesterday,
              'expires_on' => yesterday,
              'purchase_xid' => nil,
              'quantity' => nil,
              'trial' => false
            }]
          }
        end

        it 'provisions Duo Pro' do
          expect { execute_service }.to change { GitlabSubscriptions::AddOn.count }.by(1)

          expect(GitlabSubscriptions::AddOnPurchase.first.add_on).to be_code_suggestions
        end
      end

      context 'with multiple deprovision parameters' do
        let(:add_on_products) do
          {
            'duo_pro' => [{
              'started_on' => yesterday,
              'expires_on' => yesterday,
              'purchase_xid' => nil,
              'quantity' => nil,
              'trial' => false
            }],
            'duo_enterprise' => [{
              'started_on' => yesterday,
              'expires_on' => yesterday,
              'purchase_xid' => nil,
              'quantity' => nil,
              'trial' => false
            }]
          }
        end

        let!(:add_on_purchase) do
          create(
            :gitlab_subscription_add_on_purchase,
            :duo_pro,
            started_at: started_at,
            expires_on: expires_on,
            namespace: namespace,
            purchase_xid: '123',
            quantity: 2,
            trial: false
          )
        end

        it 'deprovision only add-on purchases with the same add-on name' do
          execute_service

          expect(add_on_purchase.reload.add_on).to be_code_suggestions
        end

        it 'expires date attributes' do
          execute_service

          expect(add_on_purchase.reload.started_at).to eq yesterday
          expect(add_on_purchase.expires_on).to eq yesterday
        end

        it 'does not change other attributes' do
          execute_service

          expect(add_on_purchase.reload.purchase_xid).to eq '123'
          expect(add_on_purchase.quantity).to eq 2
        end

        it 'executes successfully' do
          expect(execute_service).to be_success
          expect(execute_service.message).to eq('Nothing to provision or de-provision')
          expect(execute_service.payload).to eq({ add_on_purchases: GitlabSubscriptions::AddOnPurchase.limit(1).to_a })
        end
      end
    end

    context 'with invalid add-on name' do
      let(:add_on_products) do
        {
          'invalid_add_on' => [{
            'started_on' => started_at,
            'expires_on' => expires_on,
            'purchase_xid' => purchase_xid,
            'quantity' => quantity,
            'trial' => trial
          }]
        }
      end

      it 'returns error service response' do
        expect(execute_service).to be_error
        expect(execute_service.message).to eq("'invalid_add_on' is not a valid name")
      end

      it 'does not create any add-ons' do
        expect { execute_service }.not_to change { GitlabSubscriptions::AddOn.count }
      end

      it 'does not create any add-on purchases' do
        expect { execute_service }.not_to change { GitlabSubscriptions::AddOnPurchase.count }
      end

      it 'does not enqueue refresh user assignments worker' do
        expect(GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker)
          .not_to receive(:perform_async)

        execute_service
      end
    end

    context 'with mixed valid and invalid add-on names' do
      let(:add_on_products) do
        {
          'duo_core' => [{
            'started_on' => started_at,
            'expires_on' => expires_on,
            'purchase_xid' => 'S-A00000001',
            'quantity' => 5,
            'trial' => false
          }],
          'invalid_add_on' => [{
            'started_on' => started_at,
            'expires_on' => expires_on,
            'purchase_xid' => 'S-A00000002',
            'quantity' => quantity,
            'trial' => trial
          }]
        }
      end

      it 'returns error service response' do
        expect(execute_service).to be_error
        expect(execute_service.message).to eq("'invalid_add_on' is not a valid name")
      end

      it 'provisions valid add-ons' do
        expect { execute_service }.to change { GitlabSubscriptions::AddOn.count }.by(1)
        expect(GitlabSubscriptions::AddOn.first).to be_duo_core
      end

      it 'creates add-on purchases for valid add-ons' do
        expect { execute_service }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)
        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
          add_on: have_attributes(name: 'duo_core'),
          quantity: 5,
          namespace: namespace
        )
      end

      it 'enqueues refresh user assignments worker' do
        expect(GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker)
          .to receive(:perform_async).with(namespace.id)

        execute_service
      end
    end
  end
end
