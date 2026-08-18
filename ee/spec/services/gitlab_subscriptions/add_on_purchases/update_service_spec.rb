# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::UpdateService, :aggregate_failures, feature_category: :plan_provisioning do
  describe '#execute' do
    let_it_be(:root_namespace) { create(:group) }
    let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
    let_it_be(:purchase_xid) { 'S-A00000001' }
    let_it_be(:existing_trial) { false }

    let(:params) do
      {
        quantity: 10,
        started_on: Date.current.to_s,
        expires_on: (Date.current + 1.year).to_s,
        purchase_xid: purchase_xid
      }.merge(extra_params)
    end

    let(:extra_params) { { trial: true } }
    let(:expected_trial_value) { true }

    subject(:result) { described_class.new(namespace, add_on, params).execute }

    shared_examples 'record exists' do
      context 'when a record exists' do
        let_it_be(:started_on) { Date.current - 1.week }
        let_it_be(:expires_on) { Date.current + 6.months }
        let_it_be(:add_on_purchase) do
          create(
            :gitlab_subscription_add_on_purchase,
            namespace: namespace,
            add_on: add_on,
            quantity: 5,
            started_at: started_on,
            expires_on: expires_on,
            purchase_xid: purchase_xid,
            trial: existing_trial
          )
        end

        it 'returns a success' do
          expect(result[:status]).to eq(:success)
        end

        it 'updates the found record' do
          expect(result[:add_on_purchase]).to be_persisted
          expect(result[:add_on_purchase]).to eq(add_on_purchase)
          expect do
            result
            add_on_purchase.reload
          end.to change { add_on_purchase.quantity }.from(5).to(10)
            .and change { add_on_purchase.started_at }.from(started_on).to(params[:started_on].to_date)
            .and change { add_on_purchase.expires_on }.from(expires_on).to(params[:expires_on].to_date)

          expect(add_on_purchase.reload.trial).to eq(expected_trial_value)
        end

        it 'enqueues RefreshUserAssignmentsWorker' do
          expect(
            GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker
          ).to receive(:perform_async).with(add_on_purchase.namespace_id)

          result
        end

        context 'when passing in the add-on purchase record' do
          let(:params) do
            super().merge(add_on_purchase: add_on_purchase)
          end

          it 'reuses the passed in record instead of loading one' do
            expect(GitlabSubscriptions::AddOnPurchase).not_to receive(:find_by)

            expect(result[:status]).to eq(:success)
            expect(result[:add_on_purchase]).to eq(add_on_purchase)
          end
        end

        context 'when the add-on purchase and a new add-on are passed' do
          let_it_be(:add_on_new) { create(:gitlab_subscription_add_on, :duo_enterprise) }
          let(:params) do
            super().merge(add_on_purchase: add_on_purchase)
          end

          subject(:result) { described_class.new(namespace, add_on_new, params).execute }

          it "updates the add-on" do
            expect { result }.to change { add_on_purchase.reload.add_on }.from(add_on).to(add_on_new)
          end
        end

        context 'when creating the record failed' do
          let(:params) { super().merge(quantity: 0) }

          it 'returns an error' do
            expect { result }.not_to change { add_on_purchase.quantity }

            expect(result[:status]).to eq(:error)
            expect(result[:message]).to eq('Quantity must be greater than or equal to 1.')
            expect(result[:add_on_purchase]).to be_an_instance_of(GitlabSubscriptions::AddOnPurchase)
            expect(result[:add_on_purchase]).to eq(add_on_purchase)
          end

          it 'does not enqueue RefreshUserAssignmentsWorker' do
            expect(
              GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker
            ).not_to receive(:perform_async)

            result
          end
        end
      end
    end

    context 'when on .com', :saas do
      let_it_be_with_reload(:namespace) { root_namespace }

      before do
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      context 'when no record exists' do
        it 'returns an error' do
          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq(
            "Add-on purchase for namespace #{namespace.name} and add-on #{add_on.name.titleize} does not exist, " \
            'create a new record instead'
          )
        end
      end

      include_examples 'record exists'

      context 'when trial param is not provided' do
        let(:extra_params) { {} }
        let(:expected_trial_value) { true }

        context 'when existing add_on is a trial' do
          let_it_be(:existing_trial) { true }

          include_examples 'record exists'
        end
      end

      context 'when trial param is provided as false' do
        let(:extra_params) { { trial: false } }
        let(:expected_trial_value) { false }
        let_it_be(:existing_trial) { true }

        context 'when existing add_on is a trial' do
          include_examples 'record exists'
        end
      end
    end

    context 'when not on .com' do
      let_it_be(:namespace) { nil }

      context 'when no record exists' do
        it 'returns an error' do
          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq(
            "Add-on purchase for add-on #{add_on.name.titleize} does not exist, create a new record instead"
          )
        end
      end

      include_examples 'record exists'
    end
  end
end
