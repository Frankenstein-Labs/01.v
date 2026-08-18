# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Utils::AiFeaturesCatalogue, feature_category: :ai_abstraction_layer do
  describe 'definitions' do
    it 'has a valid :feature_category set', :aggregate_failures do
      feature_categories = Gitlab::FeatureCategories.default.categories.map(&:to_sym).to_set

      described_class::LIST.each do |action, completion|
        expect(completion[:feature_category]).to be_a(Symbol)
        expect(feature_categories)
          .to(include(completion[:feature_category]), "expected #{action} to declare a valid feature_category")
      end
    end

    it 'has all fields set', :aggregate_failures do
      described_class::LIST.each_value do |completion|
        expect(completion).to include(:service_class,
          :prompt_class,
          :maturity,
          :self_managed,
          :internal,
          :execute_method)
      end
    end
  end

  describe '#external' do
    it 'returns external actions' do
      expect(described_class.external.values.pluck(:internal))
        .not_to include(true)
    end
  end

  describe '#with_service_class' do
    it 'returns external actions' do
      expect(described_class.with_service_class.values.pluck(:service_class))
        .not_to include(nil)
    end
  end

  describe '#for_saas_only' do
    it 'returns Saas-only actions' do
      expect(described_class.for_saas_only.values.pluck(:self_managed))
        .not_to include(true)
    end
  end

  describe '#for_saas_and_sm' do
    it 'returns actions available for both SaaS and Self-Managed' do
      expect(described_class.for_saas_and_sm.values.pluck(:self_managed))
        .not_to include(false)
    end
  end

  describe '#ga' do
    it 'returns ga actions' do
      expect(described_class.ga.values.pluck(:ga))
        .not_to include(:experimental, :beta)
    end
  end

  describe '#search_by_name' do
    it 'returns defined value if name matches' do
      expect(described_class.search_by_name(:resolve_vulnerability))
        .to eq(described_class::LIST[:resolve_vulnerability])
    end

    it 'returns value found by alternate name if name does not match' do
      expect(described_class.search_by_name(:duo_chat))
        .to eq(described_class::LIST[:chat])
    end

    it 'returns nil if nothing matches' do
      expect(described_class.search_by_name(:test))
        .to be_nil
    end

    it 'returns nil when name is nil' do
      expect(described_class.search_by_name(nil)).to be_nil
    end
  end

  describe 'LIST' do
    subject(:list) { described_class::LIST }

    it 'has correct definition for :ai_catalog' do
      expect(list[:ai_catalog]).to eq({
        service_class: nil,
        prompt_class: nil,
        feature_category: :workflow_catalog,
        execute_method: nil,
        maturity: :ga,
        self_managed: true,
        internal: true
      })
    end

    it 'has correct definition for :ai_catalog_flows' do
      expect(list[:ai_catalog_flows]).to eq({
        service_class: nil,
        prompt_class: nil,
        feature_category: :workflow_catalog,
        execute_method: nil,
        maturity: :ga,
        self_managed: true,
        internal: true
      })
    end

    it 'has correct definition for :ai_catalog_third_party_flows' do
      expect(list[:ai_catalog_third_party_flows]).to eq({
        service_class: nil,
        prompt_class: nil,
        feature_category: :workflow_catalog,
        execute_method: nil,
        maturity: :ga,
        self_managed: true,
        internal: true
      })
    end
  end
end
