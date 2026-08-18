# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Aggregations::BaseLazyAggregate, feature_category: :code_quality do
  let(:query_ctx) { {} }
  let(:pending_item) { 42 }
  let(:state_key) { aggregate.state_key }
  let(:test_block) { -> { 'block result' } }
  let(:valid_subclass) do
    Class.new(described_class) do
      def initial_state
        { pending_ids: Set.new, facets: Set.new }
      end

      def queued_objects
        lazy_state[:pending_ids]
      end

      def result
        lazy_state[:facets]
      end

      def load_queued_records
        lazy_state[:facets] << :loaded
      end

      def block_params
        [:param1, :param2]
      end
    end
  end

  let(:incomplete_subclass) { Class.new(described_class) }

  before do
    stub_const('Dummy::ValidLazyAggregate', valid_subclass)
    stub_const('Dummy::IncompleteLazyAggregate', incomplete_subclass)
  end

  describe '#initialize' do
    let(:aggregate) { Dummy::ValidLazyAggregate.new(query_ctx, pending_item) }

    it 'raises a NameError if the class is anonymous' do
      expect { Class.new(described_class).new(query_ctx, pending_item) }
        .to raise_error(NameError, "Anonymous classes are not allowed")
    end

    it 'initializes lazy state in query context if not present' do
      aggregate
      expect(query_ctx[state_key]).to eq(pending_ids: Set.new([42]), facets: Set.new)
    end

    it 'uses existing lazy state if already initialized in query context' do
      query_ctx[state_key] = {
        pending_ids: Set.new([42]),
        facets: Set.new([:some_facet])
      }

      aggregate
      expect(query_ctx[state_key]).to eq(
        pending_ids: Set.new([42]),
        facets: Set.new([:some_facet])
      )
    end

    it 'assigns the lazy state to @lazy_state' do
      lazy_state = aggregate.instance_variable_get(:@lazy_state)
      expect(lazy_state).to eq(query_ctx[state_key])
    end
  end

  describe '#execute' do
    context 'when given a block' do
      let(:aggregate) { Dummy::ValidLazyAggregate.new(query_ctx, pending_item) { test_block.call } }

      it 'loads pending items and executes block' do
        result = aggregate.execute

        expect(query_ctx[state_key][:facets]).to include(:loaded)
        expect(result).to eq('block result')
      end
    end

    context 'when no block is provided' do
      let(:aggregate) { Dummy::ValidLazyAggregate.new(query_ctx, pending_item) }

      it 'returns result' do
        result = aggregate.execute
        expect(result).to eq(Set.new([:loaded]))
      end
    end

    context 'when implementation does not implement required methods' do
      let(:aggregate) { Dummy::IncompleteLazyAggregate.new(query_ctx, pending_item) }

      where(:method) do
        %i[queued_objects initial_state result load_queued_records block_params]
      end

      with_them do
        it 'raises NoMethodError' do
          expect { aggregate.send(method) }.to raise_error(NoMethodError)
        end
      end
    end
  end
end
