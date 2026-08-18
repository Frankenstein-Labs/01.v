# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::CreateService, :aggregate_failures, feature_category: :plan_provisioning do
  describe '#execute' do
    let_it_be(:add_on) { create(:gitlab_subscription_add_on) }

    let(:params) do
      {
        quantity: 10,
        started_on: Date.current.to_s,
        expires_on: (Date.current + 1.year).to_s,
        purchase_xid: 'S-A00000001',
        trial: false
      }
    end

    subject(:result) { described_class.new(namespace, add_on, params).execute }

    shared_examples "a successful add-on purchase" do |trial_value|
      it 'returns a success' do
        expect(result[:status]).to eq(:success)
      end

      it 'creates a new record' do
        expect(::Namespace.sticking).to receive(:stick).with(:namespace, namespace.id) if namespace.present?

        expect { result }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)

        expect(result[:add_on_purchase]).to be_persisted
        expect(result[:add_on_purchase]).to have_attributes(
          namespace: namespace,
          add_on: add_on,
          quantity: params[:quantity],
          started_at: params[:started_on].to_date,
          expires_on: params[:expires_on].to_date,
          purchase_xid: params[:purchase_xid],
          trial: trial_value
        )
      end
    end

    shared_examples 'no record exists' do
      context 'when no record exists' do
        include_examples 'a successful add-on purchase', false

        context 'when trial is true' do
          let(:params) { super().merge(trial: true) }

          include_examples 'a successful add-on purchase', true
        end

        context 'when trial is nil' do
          let(:params) { super().merge(trial: nil) }

          include_examples 'a successful add-on purchase', false
        end

        context 'when trial is not given' do
          let(:params) { super().tap { |params| params.delete(:trial) } }

          include_examples 'a successful add-on purchase', false
        end

        context 'when creating the record failed' do
          let(:params) { super().merge(quantity: 0) }

          it 'returns an error' do
            expect(result[:status]).to eq(:error)
            expect(result[:message]).to eq('Quantity must be greater than or equal to 1.')
            expect(result[:add_on_purchase]).to be_an_instance_of(GitlabSubscriptions::AddOnPurchase)
            expect(result[:add_on_purchase]).not_to be_persisted
            expect(GitlabSubscriptions::AddOnPurchase.count).to eq(0)
          end
        end
      end
    end

    context 'when gitlab_com_subscriptions saas feature is available' do
      let_it_be(:namespace) { create(:group) }

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when passing in an empty namespace' do
        let(:namespace) { nil }

        it 'returns a success' do
          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq('No namespace given')
        end
      end

      context 'when namespace is not a root namespace' do
        let(:namespace) { create(:group, :nested) }

        it 'returns an error' do
          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq("Namespace #{namespace.name} is not a root namespace")
        end
      end

      context 'when a record exists' do
        let!(:existing_add_on_purchase) do
          create(
            :gitlab_subscription_add_on_purchase,
            namespace: namespace,
            add_on: add_on,
            purchase_xid: params[:purchase_xid]
          )
        end

        it 'returns an error' do
          expect(::Namespace.sticking).not_to receive(:stick)

          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq(
            "Add-on purchase for namespace #{namespace.name} and add-on #{add_on.name.titleize} already exists, " \
            "update the existing record"
          )
        end
      end

      include_examples 'no record exists'

      it 'creates record with organization associated with the namespace' do
        expect { result }
          .to change { GitlabSubscriptions::AddOnPurchase.where(organization_id: namespace.organization).count }.by(1)
      end
    end

    context 'when gitlab_com_subscriptions saas feature is not available' do
      let_it_be(:organization) { create(:organization) }

      let(:namespace) { nil }

      context 'when passing in a namespace that is not a root namespace' do
        let(:namespace) { create(:group, :nested) }

        it 'returns a success' do
          expect(result[:status]).to eq(:success)
        end
      end

      context 'when a record exists' do
        let!(:existing_add_on_purchase) do
          create(
            :gitlab_subscription_add_on_purchase,
            namespace: namespace,
            add_on: add_on,
            purchase_xid: params[:purchase_xid]
          )
        end

        it 'returns an error' do
          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq(
            "Add-on purchase for add-on #{add_on.name.titleize} already exists, update the existing record"
          )
        end
      end

      include_examples 'no record exists'

      it 'creates record with first organization id' do
        expect { result }.to change {
          GitlabSubscriptions::AddOnPurchase.where(organization_id: organization.id).count
        }.by(1)
      end
    end
  end
end
