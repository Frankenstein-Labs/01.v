# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Search::ParsedQuery, feature_category: :global_search do
  let(:term) { 'search term' }
  let(:filters) { [] }

  subject(:parsed_query) { described_class.new(term, filters) }

  describe '#elasticsearch_filter_context' do
    let(:object) { 'blob' }

    context 'when there are no filters' do
      it 'returns empty filter and must_not arrays' do
        result = parsed_query.elasticsearch_filter_context(object)

        expect(result[:filter]).to be_empty
        expect(result[:must_not]).to be_empty
      end
    end

    context 'with including filters' do
      let(:filters) do
        [
          { name: :filename, value: 'test.rb', negated: false },
          { name: :extension, value: 'rb', negated: false }
        ]
      end

      it 'builds filter clauses for including filters' do
        result = parsed_query.elasticsearch_filter_context(object)

        expect(result[:filter]).to contain_exactly(
          { wildcard: { 'blob.filename' => 'test.rb' } },
          { wildcard: { 'blob.extension' => 'rb' } }
        )
        expect(result[:must_not]).to be_empty
      end
    end

    context 'with excluding filters' do
      let(:filters) do
        [
          { name: :filename, value: 'test.rb', negated: true },
          { name: :path, value: 'spec/', negated: true }
        ]
      end

      it 'builds must_not clauses for excluding filters' do
        result = parsed_query.elasticsearch_filter_context(object)

        expect(result[:filter]).to be_empty
        expect(result[:must_not]).to contain_exactly(
          { wildcard: { 'blob.filename' => 'test.rb' } },
          { wildcard: { 'blob.path' => 'spec/' } }
        )
      end
    end

    context 'with both including and excluding filters' do
      let(:filters) do
        [
          { name: :extension, value: 'rb', negated: false },
          { name: :path, value: 'spec/', negated: true }
        ]
      end

      it 'builds both filter and must_not clauses' do
        result = parsed_query.elasticsearch_filter_context(object)

        expect(result[:filter]).to contain_exactly(
          { wildcard: { 'blob.extension' => 'rb' } }
        )
        expect(result[:must_not]).to contain_exactly(
          { wildcard: { 'blob.path' => 'spec/' } }
        )
      end
    end

    context 'with custom filter type' do
      let(:filters) do
        [
          { name: :id, value: '123', type: :term, negated: false }
        ]
      end

      it 'uses the specified type instead of wildcard' do
        result = parsed_query.elasticsearch_filter_context(object)

        expect(result[:filter]).to contain_exactly(
          { term: { 'blob.id' => '123' } }
        )
      end
    end

    context 'with custom field name' do
      let(:filters) do
        [
          { name: :filename, field: :file_name, value: 'test.rb', negated: false }
        ]
      end

      it 'uses the custom field name' do
        result = parsed_query.elasticsearch_filter_context(object)

        expect(result[:filter]).to contain_exactly(
          { wildcard: { 'blob.file_name' => 'test.rb' } }
        )
      end
    end

    context 'when object is nil' do
      let(:object) { nil }
      let(:filters) do
        [
          { name: :filename, value: 'test.rb', negated: false }
        ]
      end

      it 'builds filter without object prefix' do
        result = parsed_query.elasticsearch_filter_context(object)

        expect(result[:filter]).to contain_exactly(
          { wildcard: { 'filename' => 'test.rb' } }
        )
      end
    end

    context 'when object is empty string' do
      let(:object) { '' }
      let(:filters) do
        [
          { name: :filename, value: 'test.rb', negated: false }
        ]
      end

      it 'builds filter without object prefix' do
        result = parsed_query.elasticsearch_filter_context(object)

        expect(result[:filter]).to contain_exactly(
          { wildcard: { 'filename' => 'test.rb' } }
        )
      end
    end

    context 'with complex filter combinations' do
      let(:filters) do
        [
          { name: :extension, value: 'rb', type: :wildcard, negated: false },
          { name: :id, value: '123', type: :term, negated: false },
          { name: :path, value: 'spec/', negated: true },
          { name: :author, field: :author_id, value: '456', type: :term, negated: true }
        ]
      end

      it 'builds correct filter and must_not clauses with different types and fields' do
        result = parsed_query.elasticsearch_filter_context(object)

        expect(result[:filter]).to contain_exactly(
          { wildcard: { 'blob.extension' => 'rb' } },
          { term: { 'blob.id' => '123' } }
        )
        expect(result[:must_not]).to contain_exactly(
          { wildcard: { 'blob.path' => 'spec/' } },
          { term: { 'blob.author_id' => '456' } }
        )
      end
    end
  end
end
