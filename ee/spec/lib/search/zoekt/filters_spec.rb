# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Filters, feature_category: :global_search do
  describe '.by_substring' do
    it 'returns a substring filter with required pattern' do
      expect(described_class.by_substring(pattern: 'foo')).to eq({ substring: { pattern: 'foo' } })
    end

    it 'includes optional parameters if provided' do
      result = described_class.by_substring(pattern: 'foo', case_sensitive: true, file_name: 'bar', content: 'baz')
      expect(result).to eq({ substring: { pattern: 'foo', case_sensitive: true, file_name: 'bar', content: 'baz' } })
    end
  end

  describe '.by_traversal_ids' do
    it 'raises error if traversal_ids is empty' do
      expect { described_class.by_traversal_ids([]) }.to raise_error(ArgumentError, 'Traversal IDs cannot be empty')
    end

    it 'returns a traversal_ids filter with the given IDs as a prefix search' do
      expect(described_class.by_traversal_ids('123-456-')).to eq({ meta: { key: 'traversal_ids', value: '^123-456-' } })
    end
  end

  describe '.by_repo_ids' do
    it 'raises error if ids is not an array' do
      expect { described_class.by_repo_ids('foo') }.to raise_error(ArgumentError)
    end

    it 'returns repo_ids as integers' do
      expect(described_class.by_repo_ids(['1', 2])).to eq({ repo_ids: [1, 2] })
    end

    context 'when a project ID exceeds 32-bit integer limit' do
      it 'returns a meta filter with regex pattern combining all project IDs' do
        expect(described_class.by_repo_ids([1, 2**32])).to eq(
          { meta: { key: 'project_id', value: '^(1|4294967296)$' } }
        )
      end
    end
  end

  describe '.by_regexp' do
    it 'returns a regexp filter with required regexp' do
      expect(described_class.by_regexp(regexp: 'foo')).to eq({ regexp: { regexp: 'foo' } })
    end

    it 'includes optional parameters if provided' do
      result = described_class.by_regexp(regexp: 'foo', case_sensitive: false, file_name: 'bar', content: 'baz')
      expect(result).to eq({ regexp: { regexp: 'foo', case_sensitive: false, file_name: 'bar', content: 'baz' } })
    end
  end

  describe '.and_filters' do
    it 'returns an and filter with children' do
      expect(described_class.and_filters({ a: 1 }, { b: 2 })).to eq({ and: { children: [{ a: 1 }, { b: 2 }] } })
    end
  end

  describe '.or_filters' do
    it 'returns an or filter with children' do
      expect(described_class.or_filters({ a: 1 }, { b: 2 })).to eq({ or: { children: [{ a: 1 }, { b: 2 }] } })
    end
  end

  describe '.not_filter' do
    it 'returns a not filter with child' do
      expect(described_class.not_filter({ a: 1 })).to eq({ not: { child: { a: 1 } } })
    end
  end

  describe '.by_symbol' do
    it 'returns a symbol filter' do
      expect(described_class.by_symbol('foo')).to eq({ symbol: { expr: 'foo' } })
    end
  end

  describe '.by_meta' do
    it 'returns a meta filter' do
      expect(described_class.by_meta(key: 'foo', value: 'bar')).to eq({ meta: { key: 'foo', value: 'bar' } })
    end
  end

  describe '.by_query_string' do
    using RSpec::Parameterized::TableSyntax

    where(:input_query, :expected_query) do
      'foo'                | 'case:no foo'
      'foo bar'            | 'case:no foo bar'
      'case:no foo'        | 'case:no foo'
      'case:yes foo'       | 'case:yes foo'
      'case:auto foo'      | 'case:auto foo'
      'case:auto foo'      | 'case:auto foo'
      'case: no foo'       | 'case:no case: no foo'
      'case: yes foo'      | 'case:no case: yes foo'
      'case: auto foo'     | 'case:no case: auto foo'
      'foo case:yes bar'   | 'foo case:yes bar'
    end

    with_them do
      it 'handles case modifier injection correctly' do
        expect(described_class.by_query_string(input_query)).to eq({ query_string: { query: expected_query } })
      end
    end
  end

  describe '.by_project_ids_through_meta' do
    it 'returns a meta filter with regex pattern combining all project IDs' do
      expect(described_class.by_project_ids_through_meta([1, 2])).to eq(
        { meta: { key: 'project_id', value: '^(1|2)$' } }
      )
    end

    it 'returns correct pattern for single project ID' do
      expect(described_class.by_project_ids_through_meta([123])).to eq(
        { meta: { key: 'project_id', value: '^(123)$' } }
      )
    end

    it 'returns correct pattern for multiple project IDs' do
      expect(described_class.by_project_ids_through_meta([1, 2, 3])).to eq(
        { meta: { key: 'project_id', value: '^(1|2|3)$' } }
      )
    end

    it 'raises error if ids is empty' do
      expect do
        described_class.by_project_ids_through_meta([])
      end.to raise_error(ArgumentError, 'Project IDs cannot be empty')
    end
  end
end
