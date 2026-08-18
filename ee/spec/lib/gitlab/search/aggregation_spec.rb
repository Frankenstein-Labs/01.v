# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Search::Aggregation, feature_category: :global_search do
  describe 'parsing bucket results' do
    subject(:aggregation) { described_class.new('language', aggregation_buckets) }

    context 'when elasticsearch buckets are provided' do
      let(:aggregation_buckets) do
        [
          { key: { language: 'ruby' }, doc_count: 10 },
          { key: { language: 'java' }, doc_count: 20 }
        ].map(&:with_indifferent_access)
      end

      it 'parses the results' do
        expected = [{ key: { language: 'ruby' }, count: 10 }, { key: { language: 'java' }, count: 20 }]

        expect(aggregation.buckets).to match_array(expected)
      end
    end

    context 'when elasticsearch nested buckets are provided' do
      let(:aggregation_buckets) do
        [
          {
            key_as_string: "2025-04-11T00:00:00.000Z",
            key: 1744243200000,
            doc_count: 16676,
            by_severity: {
              buckets: [
                {
                  key: 5,
                  doc_count: 9780
                },
                {
                  key: 4,
                  doc_count: 6896
                }
              ]
            }
          },
          {
            key_as_string: "2025-04-12T00:00:00.000Z",
            key: 1744416000000,
            doc_count: 3269,
            by_severity: {
              buckets: [
                {
                  key: 5,
                  doc_count: 1948
                },
                {
                  key: 4,
                  doc_count: 1321
                }
              ]
            }
          }
        ].map(&:with_indifferent_access)
      end

      it 'parses the results' do
        expected = [
          {
            key: "2025-04-11T00:00:00.000Z",
            count: 16676,
            buckets: {
              by_severity: [{ key: 5, count: 9780 }, { key: 4, count: 6896 }]
            }
          },
          {
            key: "2025-04-12T00:00:00.000Z",
            count: 3269,
            buckets: {
              by_severity: [{ key: 5, count: 1948 }, { key: 4, count: 1321 }]
            }
          }
        ]

        expect(aggregation.buckets).to match_array(expected)
      end
    end

    context 'when extra is provided' do
      let(:aggregation_buckets) do
        [
          { key: 'ruby', doc_count: 10, extra: { foo: 'bar' }.with_indifferent_access },
          { key: 'java', doc_count: 20, extra: { foo: 'baz' }.with_indifferent_access }
        ].map(&:with_indifferent_access)
      end

      it 'merges the extra field' do
        expected = [{ key: 'ruby', count: 10, foo: 'bar' }, { key: 'java', count: 20, foo: 'baz' }]

        expect(aggregation.buckets).to match_array(expected)
      end
    end

    context 'when elasticsearch buckets are not provided' do
      let(:aggregation_buckets) { nil }

      it 'parses the results' do
        expect(aggregation.buckets).to be_empty
      end
    end
  end
end
