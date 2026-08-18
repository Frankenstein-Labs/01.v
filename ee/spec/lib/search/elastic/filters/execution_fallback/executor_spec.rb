# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Filters::ExecutionFallback::Executor, feature_category: :global_search do
  let_it_be(:actor) { create(:user) }

  let(:records) do
    (1..20).map { |i| instance_double(ActiveRecord::Base, id: i) }
  end

  let(:even_only_enrichment) do
    Module.new do
      def self.normalize_filter(value)
        case value
        when Array
          value.map { |v| ActiveModel::Type::Boolean.new.cast(v) }
        else
          ActiveModel::Type::Boolean.new.cast(value)
        end
      end

      # even IDs match
      def self.even_only_filter(ids)
        ids.index_with(&:even?)
      end
    end
  end

  let(:enrichment_dummy_class) do
    Class.new.tap do |klass|
      klass.const_set(:ENRICHMENTS, [even_only_enrichment])
    end
  end

  let(:run_fetch) do
    ->(args, namespace: nil) do
      namespace ||= enrichment_dummy_class

      described_class.fetch_with_fallback(
        args,
        user: actor,
        namespace: namespace,
        result_max_records: 10,
        pagination_overfetch_window: 3
      ) do |query_args|
        if query_args[:first]
          records.first(query_args[:first])
        elsif query_args[:per_page]
          records.first(query_args[:per_page])
        else
          records
        end
      end
    end
  end

  describe '.fetch_with_fallback' do
    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(elastic_filters_execution_fallback: false)
      end

      it 'bypasses fallback completely' do
        result = run_fetch.call({ first: 2, even_only_filter: true })
        expect(result.map(&:id)).to match_array([1, 2])
      end
    end

    context 'when no fallback filters are provided' do
      it 'does not overfetch' do
        result = run_fetch.call({ first: 2 })
        expect(result.map(&:id)).to match_array([1, 2])
      end
    end

    context 'when fallback filter is active (cursor pagination)' do
      it 'overfetches but caps at result_max_records' do
        described_class.fetch_with_fallback(
          { first: 4, even_only_filter: true },
          user: actor,
          namespace: enrichment_dummy_class,
          result_max_records: 10,
          pagination_overfetch_window: 3
        ) do |query_args|
          expect(query_args[:first]).to eq(10)
          records.first(query_args[:first])
        end
      end

      it 'applies enrichment filtering' do
        result = run_fetch.call({ first: 10, even_only_filter: true })

        expect(result.map(&:id)).to match_array([2, 4, 6, 8, 10])
      end

      it 'preserves density' do
        result = run_fetch.call({ first: 2, even_only_filter: true })

        expect(result.map(&:id)).to match_array([2, 4])
      end
    end

    context 'when fallback filter is active (offset pagination)' do
      it 'correctly applies page/per_page' do
        result = run_fetch.call({ page: 2, per_page: 2, even_only_filter: true })
        expect(result.map(&:id)).to match_array([6, 8])
      end
    end

    context 'when limit is present but pagination key is treated as fallback filter' do
      let(:fake_enrichment) do
        Module.new do
          def self.first(ids)
            ids.index_with { |_id| true }
          end
        end
      end

      let(:fake_enrichment_class) do
        Class.new.tap do |klass|
          klass.const_set(:ENRICHMENTS, [fake_enrichment])
        end
      end

      it 'does not modify query_args' do
        described_class.fetch_with_fallback(
          { first: 5 },
          user: actor,
          namespace: fake_enrichment_class,
          result_max_records: 50,
          pagination_overfetch_window: 3
        ) do |query_args|
          expect(query_args).to eq({})
          records
        end
      end
    end

    context 'when fallback argument requires normalization' do
      it 'normalizes string argument before comparison' do
        result = run_fetch.call({ first: 6, even_only_filter: "true" })
        expect(result.map(&:id)).to match_array([2, 4, 6, 8, 10])
      end

      it 'calls normalize_filter on enrichment module' do
        allow(even_only_enrichment).to receive(:normalize_filter).and_call_original

        run_fetch.call({ first: 6, even_only_filter: "true" })

        expect(even_only_enrichment).to have_received(:normalize_filter).with("true")
      end
    end

    context 'when multi-value filter is provided as array' do
      it 'matches records if any value matches (OR semantics)' do
        result = run_fetch.call({ first: 6, even_only_filter: ["true"] })

        expect(result.map(&:id)).to match_array([2, 4, 6, 8, 10])
      end

      it 'matches all records when both true and false are provided' do
        result = run_fetch.call({ first: 6, even_only_filter: %w[true false] })

        expect(result.map(&:id)).to match_array([1, 2, 3, 4, 5, 6])
      end

      it 'returns only odd records when false is provided' do
        result = run_fetch.call({ first: 6, even_only_filter: ["false"] })

        expect(result.map(&:id)).to match_array([1, 3, 5, 7, 9])
      end

      it 'normalizes entire array value' do
        allow(even_only_enrichment).to receive(:normalize_filter).and_call_original

        run_fetch.call({ first: 6, even_only_filter: %w[true false] })

        expect(even_only_enrichment).to have_received(:normalize_filter).with(%w[true false])
      end
    end

    context 'when multiple fallback filters are provided' do
      let(:greater_than_five_enrichment) do
        Module.new do
          def self.greater_than_five(ids)
            ids.index_with { |id| id > 5 }
          end
        end
      end

      let(:multi_enrichment_class) do
        Class.new.tap do |klass|
          klass.const_set(:ENRICHMENTS, [even_only_enrichment, greater_than_five_enrichment])
        end
      end

      it 'intersects results from both filters (AND semantics)' do
        result = run_fetch.call(
          { first: 10, even_only_filter: true, greater_than_five: true },
          namespace: multi_enrichment_class
        )

        expect(result.map(&:id)).to match_array([6, 8, 10])
      end
    end

    context 'when dataset is already filtered by ES before fallback' do
      it 'intersects fallback filter with pre-filtered ES results' do
        result = described_class.fetch_with_fallback(
          { first: 5, even_only_filter: true },
          user: actor,
          namespace: enrichment_dummy_class,
          result_max_records: 20,
          pagination_overfetch_window: 3
        ) do |_query_args|
          # Simulate ES returning only ids 3..10
          records.select { |r| r.id.between?(3, 10) }
        end

        expect(result.map(&:id)).to match_array([4, 6, 8, 10])
      end
    end

    context 'when enrichment raises an error' do
      before do
        allow(even_only_enrichment)
          .to receive(:even_only_filter)
                .and_raise(StandardError, 'error')
      end

      it 'does not swallow the error' do
        expect do
          run_fetch.call({ first: 2, even_only_filter: true })
        end.to raise_error(StandardError, 'error')
      end
    end

    context 'when fallback filter is not supported' do
      it 'ignores unknown filters' do
        result = run_fetch.call({ first: 5, unknown_filter: true })
        expect(result.map(&:id)).to match_array([1, 2, 3, 4, 5])
      end
    end

    context 'when enrichment requires batching' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 4)
        allow(even_only_enrichment).to receive(:even_only_filter).and_call_original
      end

      it 'calls enrichment in batches' do
        result = run_fetch.call({ first: 10, even_only_filter: true })

        expect(even_only_enrichment)
          .to have_received(:even_only_filter)
                .exactly(3).times

        expect(result.map(&:id)).to match_array([2, 4, 6, 8, 10])
      end
    end

    context 'when pagination is absent' do
      it 'applies fallback and respects result_max_records' do
        result = run_fetch.call({ even_only_filter: true })
        expect(result.map(&:id)).to match_array([2, 4, 6, 8, 10])
      end
    end
  end

  context 'when enrichment class is built using Composer' do
    let(:composer_enrichment_class) do
      Class.new do
        extend Search::Elastic::Filters::ExecutionFallback::Composer

        def initialize(ids)
          @ids = ids
        end

        def even_only_filter(ids = @ids)
          ids.index_with(&:even?)
        end

        private

        def normalize_boolean(value)
          case value
          when Array
            value.map { |v| ActiveModel::Type::Boolean.new.cast(v) }
          else
            ActiveModel::Type::Boolean.new.cast(value)
          end
        end

        fallback_filter :even_only_filter, method: :even_only_filter, normalize_with: :normalize_boolean
      end
    end

    it 'works end-to-end with Composer-defined enrichment' do
      result = run_fetch.call(
        { first: 6, even_only_filter: "true" },
        namespace: composer_enrichment_class
      )

      expect(result.map(&:id)).to match_array([2, 4, 6, 8, 10])
    end

    it 'uses ENRICHMENTS built by Composer' do
      expect(composer_enrichment_class::ENRICHMENTS)
        .to eq([composer_enrichment_class])
    end
  end

  context 'when actor is not a User' do
    let(:actor) { create(:project) }

    it 'bypasses fallback completely' do
      result = run_fetch.call({ first: 6, even_only_filter: true })

      expect(result.map(&:id)).to match_array([1, 2, 3, 4, 5, 6])
    end

    describe 'when actor is nil' do
      let(:actor) { nil }

      it 'bypasses fallback completely' do
        result = run_fetch.call({ first: 6, even_only_filter: true })

        expect(result.map(&:id)).to match_array([1, 2, 3, 4, 5, 6])
      end
    end
  end

  context 'when ES returns no records' do
    it 'returns an empty array early' do
      result = described_class.fetch_with_fallback(
        { first: 5, even_only_filter: true },
        user: actor,
        namespace: enrichment_dummy_class,
        result_max_records: 10,
        pagination_overfetch_window: 3
      ) do |_query_args|
        []
      end

      expect(result).to eq([])
    end
  end
end
