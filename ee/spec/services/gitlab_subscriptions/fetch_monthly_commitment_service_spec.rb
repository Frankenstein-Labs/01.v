# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::FetchMonthlyCommitmentService, feature_category: :subscription_management do
  let_it_be(:namespace) { create(:namespace) }

  let(:client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }

  subject(:service) { described_class.new(namespace_id: namespace.id) }

  before do
    allow(Gitlab::SubscriptionPortal::SubscriptionUsageClient)
      .to receive(:new)
      .with(namespace_id: namespace.id)
      .and_return(client)
  end

  describe '#execute' do
    context 'when the client returns a successful response with credits' do
      before do
        allow(client).to receive(:get_monthly_commitment).and_return({
          success: true,
          monthlyCommitment: { totalCredits: 500 }
        })
      end

      it 'returns a success response with the total credits' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:total_credits]).to eq(500)
      end
    end

    context 'when the client returns a successful response without totalCredits' do
      before do
        allow(client).to receive(:get_monthly_commitment).and_return({
          success: true,
          monthlyCommitment: {}
        })
      end

      it 'returns a success response with 0 credits' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:total_credits]).to eq(0)
      end
    end

    context 'when the client returns a successful response without monthlyCommitment' do
      before do
        allow(client).to receive(:get_monthly_commitment).and_return({ success: true })
      end

      it 'returns a success response with 0 credits' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:total_credits]).to eq(0)
      end
    end

    context 'when the client returns an unsuccessful response' do
      before do
        allow(client).to receive(:get_monthly_commitment).and_return({ success: false })
      end

      it 'returns a success response with 0 credits' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:total_credits]).to eq(0)
      end
    end
  end
end
