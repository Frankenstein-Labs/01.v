# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::DocumentType, feature_category: :global_search do
  let(:test_klass) do
    test_klass = Class.new do
      include Search::Elastic::DocumentType
    end

    stub_const('TestKlass', test_klass)

    TestKlass
  end

  let(:instance) { test_klass.new }

  describe '#document_type' do
    context 'when class has DOCUMENT_TYPE constant' do
      before do
        test_klass.const_set(:DOCUMENT_TYPE, Project)
      end

      it 'returns the document_type' do
        expect(instance.send(:document_type)).to eq(Project)
      end
    end

    context 'when class does not have DOCUMENT_TYPE constant' do
      it 'raises NotImplementedError' do
        expect { instance.send(:document_type) }.to raise_error(NotImplementedError)
      end
    end
  end

  describe '#es_document_type' do
    context 'when class has DOCUMENT_TYPE constant' do
      before do
        test_klass.const_set(:DOCUMENT_TYPE, Project)
      end

      it 'returns the document_type in lowercase and underscored' do
        expect(instance.send(:es_document_type)).to eq('project')
      end
    end

    context 'when class does not have DOCUMENT_TYPE constant' do
      it 'raises NotImplementedError' do
        expect { instance.send(:es_document_type) }.to raise_error(NotImplementedError)
      end
    end
  end

  describe '#document_type_fields' do
    context 'when class has document_type_fields method defined' do
      let(:test_klass) do
        test_klass = Class.new do
          include Search::Elastic::DocumentType

          def document_type_fields
            'test_document_type_fields'
          end
        end

        stub_const('TestKlass', test_klass)

        TestKlass
      end

      it 'returns the document_type' do
        expect(instance.send(:document_type_fields)).to eq('test_document_type_fields')
      end
    end
  end

  context 'when class does not have document_type_fields method defined' do
    it 'raises NotImplementedError' do
      expect { instance.send(:document_type_fields) }.to raise_error(NotImplementedError)
    end
  end

  describe '#document_type_plural' do
    context 'when class has DOCUMENT_TYPE constant' do
      before do
        test_klass.const_set(:DOCUMENT_TYPE, Project)
      end

      it 'returns the document_type pluralized as a string' do
        expect(instance.send(:document_type_plural)).to eq('Projects')
      end
    end

    context 'when class does not have DOCUMENT_TYPE constant' do
      it 'raises NotImplementedError' do
        expect { instance.send(:document_type_plural) }.to raise_error(NotImplementedError)
      end
    end
  end
end
