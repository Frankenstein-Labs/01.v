# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::QueryBuilder, feature_category: :global_search do
  let(:query) { 'test_query' }
  let(:options) { { foo: 'bar' } }

  describe '.build' do
    it 'calls new with arguments and invokes build' do
      builder = instance_double(described_class)
      expect(described_class).to receive(:new).with(query: query, options: options).and_return(builder)
      expect(builder).to receive(:build)
      described_class.build(query: query, options: options)
    end
  end

  describe '#build' do
    it 'raises NotImplementedError' do
      qb = described_class.new(query: query)
      expect { qb.build }.to raise_error(NotImplementedError)
    end
  end
end
