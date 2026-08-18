# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Formats, feature_category: :global_search do
  let(:query_hash) { {} }
  let(:options) { {} }

  describe '#size' do
    subject(:size) { described_class.size(query_hash: query_hash, options: options) }

    it 'returns query_hash' do
      expect(size).to eq(query_hash)
    end

    context 'when count_only is set' do
      let(:options) { { count_only: true } }

      it 'sets size to 0' do
        expect(size).to eq({ size: 0 })
      end

      context 'when per_page is also set' do
        let(:options) { { per_page: 100, count_only: true } }

        it 'always sets size to 0' do
          expect(size).to eq({ size: 0 })
        end
      end
    end

    context 'when per_page is set' do
      let(:options) { { per_page: 100 } }

      it 'sets size to whatever is passed in' do
        expect(size).to eq({ size: 100 })
      end
    end
  end

  describe '#source_fields' do
    subject(:source_fields) { described_class.source_fields(query_hash: query_hash, options: options) }

    it 'returns query_hash' do
      expect(source_fields).to eq(query_hash)
    end

    context 'when fields is set' do
      let(:fields) { %w[id title] }
      let(:options) { { source_fields: fields } }

      it 'sets source to fields' do
        expect(source_fields).to eq({ _source: fields })
      end
    end
  end

  describe '#page' do
    subject(:page) { described_class.page(query_hash: query_hash, options: options) }

    it 'returns query_hash' do
      expect(page).to eq(query_hash)
    end

    context 'when page and per_page are both set' do
      let(:options) { { page: 2, per_page: 10 } }

      it 'calculates from using page and size' do
        expect(page).to eq({ from: 10 })
      end
    end

    context 'when only page is set' do
      let(:options) { { page: 1 } }

      it 'returns query_hash' do
        expect(page).to eq(query_hash)
      end
    end
  end
end
