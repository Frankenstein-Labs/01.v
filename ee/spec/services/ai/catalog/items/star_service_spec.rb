# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Items::StarService, feature_category: :workflow_catalog do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:item) { create(:ai_catalog_item, organization: organization) }
  let_it_be(:user) { create(:user) }

  describe '#execute' do
    context 'when starring an item' do
      subject(:result) { described_class.new(item, user, { starred: true }).execute }

      it 'returns a success response' do
        expect(result).to be_success
      end

      it 'increments the star count' do
        expect { result }.to change { item.reload.star_count }.by(1)
      end

      it 'returns the updated star count in the payload' do
        result
        expect(result.payload[:star_count]).to eq(item.reload.star_count)
      end

      context 'when the item raises ActiveRecord::RecordInvalid' do
        before do
          allow(item).to receive(:star).and_raise(ActiveRecord::RecordInvalid)
        end

        it 'returns an error response' do
          expect(result).to be_error
        end
      end
    end

    context 'when unstarring an item' do
      before_all do
        create(:ai_catalog_item_star, item: item, user: user, organization: organization)
        item.update_columns(star_count: 1)
      end

      subject(:result) { described_class.new(item, user, { starred: false }).execute }

      it 'returns a success response' do
        expect(result).to be_success
      end

      it 'decrements the star count' do
        expect { result }.to change { item.reload.star_count }.by(-1)
      end

      it 'returns the updated star count in the payload' do
        result
        expect(result.payload[:star_count]).to eq(item.reload.star_count)
      end
    end
  end
end
