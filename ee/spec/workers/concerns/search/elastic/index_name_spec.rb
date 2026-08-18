# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::IndexName, feature_category: :global_search do
  let(:test_klass) do
    test_klass = Class.new do
      include Search::Elastic::IndexName
    end

    stub_const('TestKlass', test_klass)

    TestKlass
  end

  let(:instance) { test_klass.new }

  describe '#index_name' do
    context 'when class has DOCUMENT_TYPE constant' do
      before do
        test_klass.const_set(:DOCUMENT_TYPE, document_type_class)
      end

      context 'when Search::Elastic::Types has the document type constant' do
        let(:document_type_class) do
          mock_klass = Class.new do
            def self.index_name
              'test_index_name'
            end
          end
          stub_const('MockKlass', mock_klass)

          MockKlass
        end

        before do
          stub_const('Search::Elastic::Types', class_double(::Search::Elastic::Types))

          allow(Search::Elastic::Types).to receive(:const_defined?)
            .with('MockKlass', false)
            .and_return(true)

          allow(Search::Elastic::Types).to receive(:const_get)
            .with('MockKlass', false)
            .and_return(document_type_class)
        end

        it 'returns the index name from the type class' do
          expect(instance.send(:index_name)).to eq('test_index_name')
        end
      end

      context 'when Search::Elastic::Types does not have the document type constant' do
        let(:document_type_class) do
          mock_elasticsearch = Module.new do
            def self.index_name
              'legacy_index_name'
            end
          end
          stub_const('MockElasticsearch', mock_elasticsearch)

          mock_legacy_klass = Class.new do
            def self.__elasticsearch__
              MockElasticsearch
            end
          end

          stub_const('MockLegacyKlass', mock_legacy_klass)

          MockLegacyKlass
        end

        before do
          stub_const('Search::Elastic::Types', class_double(::Search::Elastic::Types))

          allow(Search::Elastic::Types).to receive(:const_defined?)
            .with('MockLegacyKlass', false)
            .and_return(false)
        end

        it 'returns the index name from the legacy implementation' do
          expect(instance.send(:index_name)).to eq('legacy_index_name')
        end
      end
    end

    context 'when class does not have DOCUMENT_TYPE constant' do
      it 'raises NotImplementedError' do
        expect { instance.send(:index_name) }.to raise_error(NotImplementedError)
      end
    end
  end
end
