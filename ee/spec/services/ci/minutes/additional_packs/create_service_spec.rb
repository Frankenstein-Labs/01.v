# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Minutes::AdditionalPacks::CreateService, feature_category: :hosted_runners do
  include AfterNextHelpers

  describe '#execute' do
    let_it_be(:namespace) { create(:namespace) }

    subject(:result) { described_class.new(namespace, params).execute }

    context 'when a record exists' do
      let_it_be(:existing_pack) { create(:ci_minutes_additional_pack, namespace: namespace) }

      let(:params) do
        [
          { purchase_xid: existing_pack.purchase_xid, expires_at: Date.today + 1.year, number_of_minutes: 10_000 },
          { purchase_xid: SecureRandom.hex(16), expires_at: Date.today + 1.year, number_of_minutes: 1_000 }
        ]
      end

      it 'returns success' do
        expect(result[:status]).to eq :success
      end

      it 'returns the existing and newly created records' do
        expect(result[:additional_packs].size).to eq 2
        expect(result[:additional_packs].first).to eq existing_pack
        expect(result[:additional_packs].last[:purchase_xid]).to eq params.last[:purchase_xid]
      end
    end

    context 'when no record exists' do
      let(:params) do
        [
          { purchase_xid: SecureRandom.hex(16), expires_at: Date.today + 1.year, number_of_minutes: 1_000 },
          { purchase_xid: SecureRandom.hex(16), expires_at: Date.today + 1.year, number_of_minutes: 2_000 },
          { purchase_xid: SecureRandom.hex(16), expires_at: Date.today + 1.year, number_of_minutes: 3_000 }
        ]
      end

      it 'creates new records', :aggregate_failures do
        expect { result }.to change { Ci::Minutes::AdditionalPack.count }.by(3)

        result[:additional_packs].each_with_index do |pack, index|
          expect(pack).to be_persisted
          expect(pack.expires_at).to eq params[index][:expires_at]
          expect(pack.purchase_xid).to eq params[index][:purchase_xid]
          expect(pack.number_of_minutes).to eq params[index][:number_of_minutes]
          expect(pack.namespace).to eq namespace
        end
      end

      it 'kicks off reset compute minutes service' do
        expect_next(::Ci::Minutes::RefreshCachedDataService).to receive(:execute)

        result
      end

      it 'returns success' do
        expect(result[:status]).to eq :success
      end

      context 'with invalid params', :aggregate_failures do
        let(:params) { super().push({ purchase_xid: 'missing-minutes' }) }

        it 'returns an error' do
          expect(result[:status]).to eq :error
          expect(result[:message]).to eq 'Unable to save additional packs'
          expect(Ci::Minutes::AdditionalPack.count).to eq 0
        end
      end
    end
  end
end
