# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SubscriptionPortal::FeatureMetadata, feature_category: :consumables_cost_management do
  describe '::Feature' do
    it 'supports keyword initialization with all or partial attributes' do
      full = described_class::Feature.new(feature_qualified_name: 'test', feature_ai_catalog_item: 'catalog')
      partial = described_class::Feature.new(feature_qualified_name: 'partial')

      expect(full.feature_qualified_name).to eq('test')
      expect(full.feature_ai_catalog_item).to eq('catalog')
      expect(partial.feature_ai_catalog_item).to be_nil
    end
  end

  describe '::FEATURES' do
    it 'is frozen and contains dap_feature_legacy with correct metadata' do
      expect(described_class::FEATURES).to be_frozen

      feature = described_class::FEATURES[:dap_feature_legacy]
      expect(feature.feature_qualified_name).to eq('dap_feature_legacy')
      expect(feature.feature_ai_catalog_item).to be_nil
    end

    it 'prevents modification' do
      expect { described_class::FEATURES[:new] = described_class::Feature.new }.to raise_error(FrozenError)
    end
  end

  describe '.for' do
    it 'returns feature metadata for registered features' do
      feature = described_class.for(:dap_feature_legacy)

      expect(feature).to be_a(described_class::Feature)
      expect(feature.feature_qualified_name).to eq('dap_feature_legacy')
    end

    it 'returns nil for unregistered features or invalid input' do
      expect(described_class.for(:unknown)).to be_nil
      expect(described_class.for('dap_feature_legacy')).to be_nil
      expect(described_class.for(nil)).to be_nil
    end
  end
end
