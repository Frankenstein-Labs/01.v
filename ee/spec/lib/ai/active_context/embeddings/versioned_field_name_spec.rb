# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Ai::ActiveContext::Embeddings::VersionedFieldName, feature_category: :code_suggestions do
  describe '#next_field_name' do
    context 'when current_field_name is nil' do
      let(:calculator) { described_class.new }

      it 'returns embeddings_v1' do
        expect(calculator.next_field_name).to eq('embeddings_v1')
      end
    end

    context 'when current_field_name is not provided' do
      let(:calculator) { described_class.new(nil) }

      it 'returns embeddings_v1' do
        expect(calculator.next_field_name).to eq('embeddings_v1')
      end
    end

    context 'when current_field_name has valid format' do
      it 'increments the version from embeddings_v1 to embeddings_v2' do
        calculator = described_class.new('embeddings_v1')
        expect(calculator.next_field_name).to eq('embeddings_v2')
      end

      it 'increments the version from embeddings_v5 to embeddings_v6' do
        calculator = described_class.new('embeddings_v5')
        expect(calculator.next_field_name).to eq('embeddings_v6')
      end

      it 'increments the version from custom_field_v99 to custom_field_v100' do
        calculator = described_class.new('custom_field_v99')
        expect(calculator.next_field_name).to eq('custom_field_v100')
      end

      it 'handles field names with multiple underscores in the base' do
        calculator = described_class.new('my_custom_embeddings_v3')
        expect(calculator.next_field_name).to eq('my_custom_embeddings_v4')
      end

      it 'handles field names with numbers in the base' do
        calculator = described_class.new('embeddings2_v1')
        expect(calculator.next_field_name).to eq('embeddings2_v2')
      end

      it 'allows field names starting with number' do
        calculator = described_class.new('1embeddings_v1')
        expect(calculator.next_field_name).to eq('1embeddings_v2')
      end

      it 'allows field names with double underscores' do
        calculator = described_class.new('embeddings__v1')
        expect(calculator.next_field_name).to eq('embeddings__v2')
      end
    end

    context 'when current_field_name has invalid format' do
      it 'raises InvalidFieldName when missing version suffix' do
        calculator = described_class.new('embeddings')
        expect { calculator.next_field_name }.to raise_error(
          described_class::InvalidFieldName,
          "Field name 'embeddings' does not match expected format (e.g., 'embeddings_v1')"
        )
      end

      it 'raises InvalidFieldName when version suffix has letters' do
        calculator = described_class.new('embeddings_va')
        expect { calculator.next_field_name }.to raise_error(
          described_class::InvalidFieldName,
          "Field name 'embeddings_va' does not match expected format (e.g., 'embeddings_v1')"
        )
      end

      it 'raises InvalidFieldName when field name contains uppercase letters' do
        calculator = described_class.new('Embeddings_v1')
        expect { calculator.next_field_name }.to raise_error(
          described_class::InvalidFieldName,
          "Field name 'Embeddings_v1' does not match expected format (e.g., 'embeddings_v1')"
        )
      end

      it 'raises InvalidFieldName when field name contains special characters' do
        calculator = described_class.new('embeddings-field_v1')
        expect { calculator.next_field_name }.to raise_error(
          described_class::InvalidFieldName,
          "Field name 'embeddings-field_v1' does not match expected format (e.g., 'embeddings_v1')"
        )
      end

      it 'raises InvalidFieldName when version is missing digits' do
        calculator = described_class.new('embeddings_v')
        expect { calculator.next_field_name }.to raise_error(
          described_class::InvalidFieldName,
          "Field name 'embeddings_v' does not match expected format (e.g., 'embeddings_v1')"
        )
      end
    end
  end
end
