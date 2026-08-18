# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::BoolExpr, feature_category: :global_search do
  subject(:bool_expr) { described_class.new }

  it 'sets defaults', :aggregate_failures do
    expect(bool_expr[:must]).to eq([])
    expect(bool_expr[:must_not]).to eq([])
    expect(bool_expr[:should]).to eq([])
    expect(bool_expr[:filter]).to eq([])
    expect(bool_expr[:minimum_should_match]).to be_nil
  end

  describe '#reset!', :aggregate_failures do
    it 'resets to defaults' do
      bool_expr[:must] = [1]
      bool_expr[:must_not] = [2]
      bool_expr[:should] = [3]
      bool_expr[:filter] = [4]
      bool_expr[:minimum_should_match] = 5

      bool_expr.reset!

      expect(bool_expr[:must]).to eq([])
      expect(bool_expr[:must_not]).to eq([])
      expect(bool_expr[:should]).to eq([])
      expect(bool_expr[:filter]).to eq([])
      expect(bool_expr[:minimum_should_match]).to be_nil
    end
  end

  describe '#to_h' do
    it 'returns a hash with empty values removed' do
      bool_expr[:must] = [1]
      bool_expr[:should] = [3]
      bool_expr[:minimum_should_match] = 5

      expected_hash = {
        must: [1],
        should: [3],
        minimum_should_match: 5
      }

      expect(bool_expr.to_h).to eq(expected_hash)
    end
  end

  describe '#empty?' do
    context 'when the bool expression is empty' do
      it 'returns true' do
        expect(bool_expr.empty?).to be(true)
      end
    end

    context 'when the bool expression has values' do
      it 'returns false' do
        bool_expr[:must] = [2]
        bool_expr[:should] = [4]

        expect(bool_expr.empty?).to be(false)
      end
    end
  end

  describe '#to_json' do
    it 'returns a json string with empty values removed' do
      bool_expr[:must] = [2]
      bool_expr[:should] = [4]
      bool_expr[:minimum_should_match] = 6

      expected_json = {
        must: [2],
        should: [4],
        minimum_should_match: 6
      }.to_json

      expect(bool_expr.to_json).to eq(expected_json)
    end
  end

  describe '#to_bool_query' do
    context 'when the bool expression is empty' do
      it 'returns nil' do
        expect(bool_expr.to_bool_query).to be_nil
      end
    end

    context 'when the bool expression has only must clauses' do
      it 'returns a bool query with must clauses' do
        bool_expr[:must] = [{ term: { status: 'active' } }]

        expected_query = {
          bool: {
            must: [{ term: { status: 'active' } }]
          }
        }

        expect(bool_expr.to_bool_query).to eq(expected_query)
      end
    end

    context 'when the bool expression has only must_not clauses' do
      it 'returns a bool query with must_not clauses' do
        bool_expr[:must_not] = [{ term: { status: 'deleted' } }]

        expected_query = {
          bool: {
            must_not: [{ term: { status: 'deleted' } }]
          }
        }

        expect(bool_expr.to_bool_query).to eq(expected_query)
      end
    end

    context 'when the bool expression has only filter clauses' do
      it 'returns a bool query with filter clauses' do
        bool_expr[:filter] = [{ range: { created_at: { gte: '2023-01-01' } } }]

        expected_query = {
          bool: {
            filter: [{ range: { created_at: { gte: '2023-01-01' } } }]
          }
        }

        expect(bool_expr.to_bool_query).to eq(expected_query)
      end
    end

    context 'when the bool expression has should clauses' do
      it 'returns a bool query with should clauses and sets minimum_should_match to 1' do
        bool_expr[:should] = [{ term: { category: 'bug' } }, { term: { category: 'feature' } }]

        expected_query = {
          bool: {
            should: [{ term: { category: 'bug' } }, { term: { category: 'feature' } }],
            minimum_should_match: 1
          }
        }

        expect(bool_expr.to_bool_query).to eq(expected_query)
      end

      it 'does not overwrite existing minimum_should_match value' do
        bool_expr[:should] = [{ term: { priority: 'high' } }]
        bool_expr[:minimum_should_match] = 5

        expected_query = {
          bool: {
            should: [{ term: { priority: 'high' } }],
            minimum_should_match: 5
          }
        }

        expect(bool_expr.to_bool_query).to eq(expected_query)
      end
    end

    context 'when the bool expression has multiple clause types' do
      it 'returns a bool query with all clause types' do
        bool_expr[:must] = [{ term: { status: 'active' } }]
        bool_expr[:must_not] = [{ term: { archived: true } }]
        bool_expr[:should] = [{ term: { priority: 'high' } }]
        bool_expr[:filter] = [{ range: { created_at: { gte: '2023-01-01' } } }]

        expected_query = {
          bool: {
            must: [{ term: { status: 'active' } }],
            must_not: [{ term: { archived: true } }],
            should: [{ term: { priority: 'high' } }],
            filter: [{ range: { created_at: { gte: '2023-01-01' } } }],
            minimum_should_match: 1
          }
        }

        expect(bool_expr.to_bool_query).to eq(expected_query)
      end
    end

    context 'when the bool expression has clauses but no should clauses' do
      it 'does not set minimum_should_match' do
        bool_expr[:must] = [{ term: { status: 'active' } }]
        bool_expr[:filter] = [{ range: { created_at: { gte: '2023-01-01' } } }]

        expected_query = {
          bool: {
            must: [{ term: { status: 'active' } }],
            filter: [{ range: { created_at: { gte: '2023-01-01' } } }]
          }
        }

        expect(bool_expr.to_bool_query).to eq(expected_query)
      end
    end
  end

  describe '#dup' do
    subject(:duplicated) { bool_expr.dup }

    context 'when the original bool expression is empty' do
      it 'returns a new empty bool expression' do
        expect(duplicated).to be_a(described_class)
        expect(duplicated).not_to be(bool_expr)
        expect(duplicated.empty?).to be(true)
      end
    end

    context 'when the original bool expression has simple values' do
      before do
        bool_expr[:must] = [{ term: { status: 'active' } }]
        bool_expr[:must_not] = [{ term: { archived: true } }]
        bool_expr[:should] = [{ term: { priority: 'high' } }]
        bool_expr[:filter] = [{ range: { created_at: { gte: '2023-01-01' } } }]
        bool_expr[:minimum_should_match] = 2
      end

      it 'creates an independent copy with the same values' do
        expect(duplicated).to be_a(described_class)
        expect(duplicated).not_to be(bool_expr)
        expect(duplicated.eql?(bool_expr)).to be(true)
      end

      it 'deep copies all array fields' do
        expect(duplicated[:must]).to eq(bool_expr[:must])
        expect(duplicated[:must]).not_to be(bool_expr[:must])

        expect(duplicated[:must_not]).to eq(bool_expr[:must_not])
        expect(duplicated[:must_not]).not_to be(bool_expr[:must_not])

        expect(duplicated[:should]).to eq(bool_expr[:should])
        expect(duplicated[:should]).not_to be(bool_expr[:should])

        expect(duplicated[:filter]).to eq(bool_expr[:filter])
        expect(duplicated[:filter]).not_to be(bool_expr[:filter])
      end

      it 'copies scalar values' do
        expect(duplicated[:minimum_should_match]).to eq(bool_expr[:minimum_should_match])
      end

      it 'allows independent modification of arrays' do
        duplicated[:must] << { term: { new_field: 'new_value' } }

        expect(duplicated[:must].length).to eq(2)
        expect(bool_expr[:must].length).to eq(1)
        expect(bool_expr[:must]).not_to include({ term: { new_field: 'new_value' } })
      end

      it 'allows independent modification of scalar values' do
        duplicated[:minimum_should_match] = 5

        expect(duplicated[:minimum_should_match]).to eq(5)
        expect(bool_expr[:minimum_should_match]).to eq(2)
      end
    end

    context 'when the original bool expression has nested structures' do
      before do
        bool_expr[:must] = [
          {
            bool: {
              must: [{ term: { status: 'active' } }],
              should: [
                { term: { priority: 'high' } },
                { range: { score: { gte: 80 } } }
              ]
            }
          }
        ]
        bool_expr[:filter] = [
          {
            nested: {
              path: 'comments',
              query: {
                bool: {
                  must: [{ term: { 'comments.approved': true } }]
                }
              }
            }
          }
        ]
      end

      it 'deep copies nested hash structures' do
        expect(duplicated[:must]).to eq(bool_expr[:must])
        expect(duplicated[:must]).not_to be(bool_expr[:must])

        # Verify nested hashes are also copied
        original_nested_bool = bool_expr[:must][0][:bool]
        duplicated_nested_bool = duplicated[:must][0][:bool]

        expect(duplicated_nested_bool).to eq(original_nested_bool)
        expect(duplicated_nested_bool).not_to be(original_nested_bool)
        expect(duplicated_nested_bool[:must]).not_to be(original_nested_bool[:must])
        expect(duplicated_nested_bool[:should]).not_to be(original_nested_bool[:should])
      end

      it 'allows independent modification of nested structures' do
        # Modify nested structure in duplicated copy
        duplicated[:must][0][:bool][:must] << { term: { new_nested_field: 'value' } }

        expect(duplicated[:must][0][:bool][:must].length).to eq(2)
        expect(bool_expr[:must][0][:bool][:must].length).to eq(1)
        expect(bool_expr[:must][0][:bool][:must]).not_to include({ term: { new_nested_field: 'value' } })
      end

      it 'deep copies complex nested structures' do
        original_nested_query = bool_expr[:filter][0][:nested][:query]
        duplicated_nested_query = duplicated[:filter][0][:nested][:query]

        expect(duplicated_nested_query).to eq(original_nested_query)
        expect(duplicated_nested_query).not_to be(original_nested_query)
        expect(duplicated_nested_query[:bool]).not_to be(original_nested_query[:bool])
        expect(duplicated_nested_query[:bool][:must]).not_to be(original_nested_query[:bool][:must])
      end
    end

    context 'when the original bool expression has arrays of arrays' do
      before do
        bool_expr[:must] = [
          {
            terms: {
              tags: %w[ruby rails elasticsearch]
            }
          }
        ]
        bool_expr[:should] = [
          {
            bool: {
              must: [
                { terms: { categories: %w[bug feature] } },
                { terms: { labels: %w[urgent review] } }
              ]
            }
          }
        ]
      end

      it 'deep copies arrays within hash values' do
        original_tags = bool_expr[:must][0][:terms][:tags]
        duplicated_tags = duplicated[:must][0][:terms][:tags]

        expect(duplicated_tags).to eq(original_tags)
        expect(duplicated_tags).not_to be(original_tags)
      end

      it 'allows independent modification of nested arrays' do
        duplicated[:must][0][:terms][:tags] << 'new_tag'

        expect(duplicated[:must][0][:terms][:tags]).to include('new_tag')
        expect(bool_expr[:must][0][:terms][:tags]).not_to include('new_tag')
      end

      it 'deep copies nested arrays in complex structures' do
        original_categories = bool_expr[:should][0][:bool][:must][0][:terms][:categories]
        duplicated_categories = duplicated[:should][0][:bool][:must][0][:terms][:categories]

        expect(duplicated_categories).to eq(original_categories)
        expect(duplicated_categories).not_to be(original_categories)

        # Modify duplicated nested array
        duplicated_categories << 'enhancement'

        expect(original_categories).not_to include('enhancement')
        expect(duplicated_categories).to include('enhancement')
      end
    end

    context 'when the original bool expression has mixed data types' do
      before do
        bool_expr[:must] = [
          { term: { id: 123 } },
          { term: { active: true } },
          { term: { name: 'test' } },
          { term: { score: 95.5 } },
          { term: { tags: nil } }
        ]
      end

      it 'preserves all data types correctly' do
        expect(duplicated[:must][0][:term][:id]).to eq(123)
        expect(duplicated[:must][1][:term][:active]).to be(true)
        expect(duplicated[:must][2][:term][:name]).to eq('test')
        expect(duplicated[:must][3][:term][:score]).to eq(95.5)
        expect(duplicated[:must][4][:term][:tags]).to be_nil
      end

      it 'creates independent copies for all data types' do
        duplicated[:must][0][:term][:id] = 456
        duplicated[:must][1][:term][:active] = false
        duplicated[:must][2][:term][:name] = 'modified'

        expect(bool_expr[:must][0][:term][:id]).to eq(123)
        expect(bool_expr[:must][1][:term][:active]).to be(true)
        expect(bool_expr[:must][2][:term][:name]).to eq('test')
      end
    end
  end

  describe '#eql?' do
    let(:another_bool_expr) { described_class.new }

    subject(:eql) { bool_expr.eql?(another_bool_expr) }

    context 'when the other bool_expr has the same values' do
      it 'returns true' do
        bool_expr[:must] = [1]
        bool_expr[:filter] = [0]

        another_bool_expr[:must] = [1]
        another_bool_expr[:filter] = [0]

        expect(eql).to be(true)
      end
    end

    context 'when the other bool_expr does not have the same values' do
      it 'returns false' do
        bool_expr[:must] = [10]
        bool_expr[:filter] = [0]

        another_bool_expr[:must] = [1]
        another_bool_expr[:filter] = [0]

        expect(eql).to be(false)
      end
    end
  end
end
