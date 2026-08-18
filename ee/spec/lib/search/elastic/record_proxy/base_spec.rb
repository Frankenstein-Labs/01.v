# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::RecordProxy::Base, feature_category: :global_search do
  let(:mock_record_class) { Class.new { attr_accessor :id, :name, :status, :custom_method, :error_method } }
  let(:mock_record) { instance_double(mock_record_class, id: 1, name: 'test_record', status: 'active') }

  let(:proxy) { described_class.new(mock_record) }

  describe 'inheritance' do
    it 'inherits from SimpleDelegator' do
      expect(described_class.superclass).to eq(SimpleDelegator)
    end
  end

  describe 'delegation' do
    it 'delegates method calls to the underlying record' do
      expect(proxy.id).to eq(1)
      expect(proxy.name).to eq('test_record')
      expect(proxy.status).to eq('active')
    end

    it 'delegates custom methods to the underlying record' do
      allow(mock_record).to receive(:custom_method).and_return('custom_value')

      expect(proxy.custom_method).to eq('custom_value')
    end
  end

  describe '#enhance_with_data' do
    let(:enhancement_data) do
      {
        enhanced_method: 'enhanced_value',
        another_method: 42,
        complex_method: { key: 'value' }
      }
    end

    it 'defines singleton methods for each key-value pair in the data hash' do
      proxy.enhance_with_data(enhancement_data)

      expect(proxy.enhanced_method).to eq('enhanced_value')
      expect(proxy.another_method).to eq(42)
      expect(proxy.complex_method).to eq({ key: 'value' })
    end

    it 'enhanced methods take precedence over delegated methods' do
      expect(proxy.name).to eq('test_record')

      proxy.enhance_with_data({ name: 'enhanced_name' })
      expect(proxy.name).to eq('enhanced_name')

      expect(proxy.id).to eq(1)
    end

    it 'supports method introspection for enhanced methods' do
      proxy.enhance_with_data({ enhanced_method: 'enhanced_value' })

      expect(proxy.respond_to?(:enhanced_method)).to be(true)
      expect(proxy.method(:enhanced_method).owner).to be < described_class
    end
  end

  describe 'error handling' do
    it 'raises NoMethodError for truly undefined methods' do
      expect { proxy.truly_undefined_method }.to raise_error(NoMethodError)
    end

    it 'propagates errors from the underlying record' do
      allow(mock_record).to receive(:error_method).and_raise(StandardError, 'Record error')

      expect { proxy.error_method }.to raise_error(StandardError, 'Record error')
    end
  end
end
