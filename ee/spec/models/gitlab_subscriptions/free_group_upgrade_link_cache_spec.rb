# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::FreeGroupUpgradeLinkCache, feature_category: :subscription_management do
  let(:user_id) { 123 }

  describe '.get' do
    context 'when cache is empty', :use_clean_rails_memory_store_caching do
      it 'executes the block' do
        result = described_class.get(user_id) { 'value' }
        expect(result).to eq('value')
      end

      it 'returns cached value on subsequent calls' do
        described_class.get(user_id) { 'value1' }
        result = described_class.get(user_id) { 'value2' }
        expect(result).to eq('value1')
      end
    end

    context 'when cache is populated', :use_clean_rails_memory_store_caching do
      before do
        described_class.get(user_id) { 'cached' }
      end

      it 'returns cached value without executing block' do
        block_executed = false
        result = described_class.get(user_id) { block_executed = true }
        expect(result).to eq('cached')
        expect(block_executed).to be false
      end
    end
  end

  describe '.invalidate' do
    context 'when cache is populated', :use_clean_rails_memory_store_caching do
      before do
        described_class.get(user_id) { 'cached' }
      end

      it 'removes the cached value' do
        described_class.invalidate(user_id)
        result = described_class.get(user_id) { 'new' }
        expect(result).to eq('new')
      end
    end
  end
end
