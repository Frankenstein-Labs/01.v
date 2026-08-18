# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::ExpireService, :aggregate_failures, feature_category: :plan_provisioning do
  describe '#execute' do
    let!(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    subject(:result) { described_class.new(add_on_purchase).execute }

    context 'when add-on purchase is already expired' do
      let!(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, expires_on: 1.week.ago.to_date) }

      it 'does not update the add-on purchase again' do
        expect do
          result
          add_on_purchase.reload
        end.not_to change { add_on_purchase }

        expect(result[:status]).to eq(:success)
        expect(result[:add_on_purchase]).to eq(nil)
      end
    end

    context 'when update fails' do
      before do
        errors = ActiveModel::Errors.new(add_on_purchase).tap { |e| e.add(:base, 'error message') }

        allow(add_on_purchase).to receive_messages(update: false, errors: errors)
      end

      it 'returns an error' do
        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq('error message.')
        expect(result[:add_on_purchase]).to be_an_instance_of(GitlabSubscriptions::AddOnPurchase)
      end
    end

    it 'updates the expiration date' do
      expect do
        result
        add_on_purchase.reload
      end.to change { add_on_purchase.expires_on }.to(Date.yesterday)

      expect(result[:status]).to eq(:success)
      expect(result[:add_on_purchase]).to eq(nil)
    end
  end
end
