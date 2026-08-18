# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiCatalogPinnedVersion'], feature_category: :workflow_catalog do
  using RSpec::Parameterized::TableSyntax

  specify { expect(described_class.graphql_name).to eq('AiCatalogPinnedVersion') }

  describe '.coerce_input' do
    subject(:input) { described_class.coerce_isolated_input(value) }

    context 'when the value is nil, or a valid n.n.n string' do
      where(:value) { [nil, '1.0.0', '1.2.3', '10.0.0', '1.10.10', '9.99.99', '100.0.0'] }

      with_them do
        it 'returns the input unchanged' do
          expect(input).to eq(value)
        end
      end
    end

    context 'when the value is invalid' do
      where(:value) do
        ['', '0.0.0', '0.1.2', '1', '1.2', '1.2.3.4', '01.2.3', '1.01.2', '1.2.03',
          'v1.2.3', '1.2.3-beta', 'a.b.c', ' 1.2.3', '1.2.3 ']
      end

      with_them do
        it 'raises a GraphQL::CoercionError' do
          expect { input }
            .to raise_error(GraphQL::CoercionError)
            .with_message(/is not a valid pinned version/)
        end
      end
    end

    context 'when the value is not a string' do
      let(:value) { 123 }

      it 'raises a GraphQL::CoercionError' do
        expect { input }
          .to raise_error(GraphQL::CoercionError)
          .with_message(/is not a valid pinned version/)
      end
    end
  end

  describe '.coerce_result' do
    it 'preserves nil' do
      expect(described_class.coerce_isolated_result(nil)).to be_nil
    end

    it 'coerces a symbol to a string' do
      expect(described_class.coerce_isolated_result(:'1.2.3')).to eq('1.2.3')
    end
  end
end
