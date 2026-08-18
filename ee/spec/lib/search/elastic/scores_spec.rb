# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe ::Search::Elastic::Scores, feature_category: :global_search do
  let(:fixtures_path) { 'ee/spec/fixtures/search/elastic/scores' }

  let(:query_hash) do
    { query: { bool: { must: [], filter: [{ term: { type: 'project' } }] } }, highlight: { fields: {} } }
  end

  let(:functions) do
    [
      described_class.field_value_function(field: 'star_count'),
      described_class.filter_weight_function(filter: { term: { forked: true } }, weight: 0.5)
    ]
  end

  def load_fixture(filename)
    json = File.read(Rails.root.join(fixtures_path, filename))
    ::Gitlab::Json.safe_parse(json).deep_symbolize_keys
  end

  describe '.wrap' do
    subject(:result) { described_class.wrap(query_hash: query_hash, options: options) }

    context 'when score_functions are set and no sort' do
      let(:options) { { score_functions: functions } }

      it 'wraps the query in a function_score' do
        expect(result).to eq(load_fixture('wrap_with_functions.json'))
      end

      it 'does not mutate the input query_hash' do
        original = query_hash.dup
        result
        expect(query_hash).to eq(original)
      end
    end

    context 'when score_functions is absent' do
      let(:options) { {} }

      it 'returns the query hash unchanged' do
        expect(result).to eq(query_hash)
      end
    end

    context 'when a sort is present in query_hash' do
      let(:options) { { score_functions: functions } }
      let(:query_hash) { super().merge(sort: { created_at: { order: 'desc' } }) }

      it 'returns the query hash unchanged' do
        expect(result).to eq(query_hash)
      end
    end
  end

  describe '.field_value_function' do
    it 'returns a field_value_factor hash with ln2p modifier and missing: 0 by default' do
      expect(described_class.field_value_function(field: 'star_count')).to eq(
        { field_value_factor: { field: 'star_count', modifier: 'ln2p', missing: 0 } }
      )
    end

    it 'accepts a custom modifier' do
      expect(described_class.field_value_function(field: 'star_count', modifier: 'sqrt')).to eq(
        { field_value_factor: { field: 'star_count', modifier: 'sqrt', missing: 0 } }
      )
    end
  end

  describe '.filter_weight_function' do
    it 'returns a filter and weight hash' do
      expect(described_class.filter_weight_function(filter: { term: { forked: true } }, weight: 0.5)).to eq(
        { filter: { term: { forked: true } }, weight: 0.5 }
      )
    end
  end
end
