# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::QueryBuilder, feature_category: :global_search do
  let(:stub_module) do
    Module.new do
      def self.method_one(query_hash:, **) = query_hash
      def self.method_two(query_hash:, **) = query_hash
    end
  end

  let(:query) { 'test' }
  let(:options) { {} }

  let(:subclass) do
    stub_mod = stub_module

    Class.new(described_class) do
      const_set(:QUERY_COMPONENTS, { stub_mod => %i[method_one method_two] }.freeze)
    end
  end

  let(:empty_subclass) do
    Class.new(described_class)
  end

  subject(:builder) { subclass.new(query: query, options: options) }

  describe '#build' do
    it 'calls prepare_options before build_initial_query_hash' do
      expect(builder).to receive(:prepare_options).ordered
      expect(builder).to receive(:build_initial_query_hash).ordered.and_call_original
      allow(stub_module).to receive_messages(method_one: {}, method_two: {})
      builder.build
    end

    it 'passes query_hash through each component in order' do
      initial = { query: { bool: ::Search::Elastic::BoolExpr.new } }
      after_one = initial.merge(one: true)
      after_two = after_one.merge(two: true)

      allow(builder).to receive(:build_initial_query_hash).and_return(initial)
      allow(stub_module).to receive(:method_one).with(query_hash: initial, options: anything).and_return(after_one)
      allow(stub_module).to receive(:method_two).with(query_hash: after_one, options: anything).and_return(after_two)

      expect(builder.build).to eq(after_two)
    end
  end

  context 'when a component has no migration guard' do
    it 'always applies the method' do
      expect(stub_module).to receive(:method_one).with(query_hash: anything, options: anything).and_return({})
      expect(stub_module).to receive(:method_two).with(query_hash: anything, options: anything).and_return({})

      builder.build
    end
  end

  context 'when a component has a migration guard' do
    let(:subclass) do
      stub_mod = stub_module

      Class.new(described_class) do
        const_set(:QUERY_COMPONENTS, { stub_mod => [{ method: :method_one, migration: :dummy }, :method_two] }.freeze)
      end
    end

    context 'when the migration has finished' do
      before do
        allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).with(:dummy).and_return(true)
      end

      it 'applies the guarded method' do
        expect(stub_module).to receive(:method_one).with(query_hash: anything, options: anything).and_return({})
        expect(stub_module).to receive(:method_two).with(query_hash: anything, options: anything).and_return({})

        builder.build
      end
    end

    context 'when the migration has not finished' do
      before do
        allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).with(:dummy).and_return(false)
      end

      it 'skips the guarded method but applies others' do
        expect(stub_module).not_to receive(:method_one)
        expect(stub_module).to receive(:method_two).with(query_hash: anything, options: anything).and_return({})

        builder.build
      end
    end

    context 'when a component has an unless_migration guard' do
      let(:subclass) do
        stub_mod = stub_module

        Class.new(described_class) do
          const_set(:QUERY_COMPONENTS,
            { stub_mod => [{ method: :method_one, unless_migration: :dummy }, :method_two] }.freeze)
        end
      end

      context 'when the migration has finished' do
        before do
          allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).with(:dummy).and_return(true)
        end

        it 'skips the guarded method but applies others' do
          expect(stub_module).not_to receive(:method_one)
          expect(stub_module).to receive(:method_two).with(query_hash: anything, options: anything).and_return({})

          builder.build
        end
      end

      context 'when the migration has not finished' do
        before do
          allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).with(:dummy).and_return(false)
        end

        it 'applies the guarded method' do
          expect(stub_module).to receive(:method_one).with(query_hash: anything, options: anything).and_return({})
          expect(stub_module).to receive(:method_two).with(query_hash: anything, options: anything).and_return({})

          builder.build
        end
      end
    end

    context 'when skipping size zero' do
      let(:subclass) do
        stub_mod = stub_module

        Class.new(described_class) do
          const_set(:QUERY_COMPONENTS,
            { stub_mod => [{ method: :method_one, skip_if_size_zero: true }, :method_two] }.freeze)
        end
      end

      before do
        allow(stub_module).to receive(:method_one).with(query_hash: anything, options: anything).and_return({})
        allow(stub_module).to receive(:method_two).with(query_hash: anything,
          options: anything).and_return({ size: size })
      end

      context 'when size is greater than zero' do
        let(:size) { 1 }

        it 'calls the skipped method' do
          builder.build

          expect(stub_module).to have_received(:method_one)
          expect(stub_module).to have_received(:method_two)
        end
      end

      context 'when size is zero' do
        let(:size) { 0 }

        it 'does not call the skipped method' do
          builder.build

          expect(stub_module).not_to have_received(:method_one)
          expect(stub_module).to have_received(:method_two)
        end
      end
    end
  end

  describe '#build_initial_query_hash' do
    subject(:builder) { empty_subclass.new(query: query, options: options) }

    it 'returns a blank bool query hash' do
      result = builder.build

      expect(result).to have_key(:query)
      expect(result[:query]).to have_key(:bool)
      expect(result[:query][:bool]).to be_a(::Search::Elastic::BoolExpr)
    end
  end

  describe '#prepare_options' do
    subject(:builder) { empty_subclass.new(query: query, options: options) }

    it 'is a no-op by default' do
      expect { builder.build }.not_to raise_error
    end
  end

  describe 'QUERY_COMPONENTS' do
    it 'is empty on the base class' do
      expect(described_class::QUERY_COMPONENTS).to eq({})
    end

    it 'can be overridden by subclasses' do
      expect(subclass::QUERY_COMPONENTS).not_to be_empty
    end
  end

  describe 'SCORE_COMPONENTS' do
    it 'is empty on the base class' do
      expect(described_class::SCORE_COMPONENTS).to eq({})
    end

    it 'can be overridden by subclasses' do
      stub_mod = stub_module

      subclass = Class.new(described_class) do
        const_set(:SCORE_COMPONENTS, { stub_mod => [:method_one] }.freeze)
      end

      expect(subclass::SCORE_COMPONENTS).not_to be_empty
    end
  end

  context 'when score components are defined' do
    let(:score_module) do
      Module.new do
        def self.apply_score(query_hash:, **)
          query_hash.merge(scored: true)
        end
      end
    end

    let(:subclass) do
      stub_mod = stub_module
      score_mod = score_module

      Class.new(described_class) do
        const_set(:QUERY_COMPONENTS, { stub_mod => [:method_one] }.freeze)
        const_set(:SCORE_COMPONENTS, { score_mod => [:apply_score] }.freeze)
      end
    end

    before do
      allow(stub_module).to receive(:method_one)
        .with(query_hash: anything, options: anything)
        .and_return({ size: 10 })
    end

    it 'applies score components' do
      result = builder.build

      expect(result[:scored]).to be(true)
    end

    it 'skips score components when size is zero' do
      allow(stub_module).to receive(:method_one)
        .with(query_hash: anything, options: anything)
        .and_return({ size: 0 })

      result = builder.build

      expect(result[:scored]).to be_nil
    end

    context 'with migration guards' do
      let(:subclass) do
        score_mod = score_module

        Class.new(described_class) do
          const_set(:SCORE_COMPONENTS,
            { score_mod => [{ method: :apply_score, migration: :test_migration }] }.freeze)
        end
      end

      context 'when migration has finished' do
        before do
          allow(::Elastic::DataMigrationService)
            .to receive(:migration_has_finished?)
            .with(:test_migration)
            .and_return(true)
        end

        it 'applies the score component' do
          expect(score_module).to receive(:apply_score)
          builder.build
        end
      end

      context 'when migration has not finished' do
        before do
          allow(::Elastic::DataMigrationService)
            .to receive(:migration_has_finished?)
            .with(:test_migration)
            .and_return(false)
        end

        it 'skips the score component' do
          expect(score_module).not_to receive(:apply_score)
          builder.build
        end
      end
    end

    context 'with unless_migration guards' do
      let(:subclass) do
        score_mod = score_module

        Class.new(described_class) do
          const_set(:SCORE_COMPONENTS,
            { score_mod => [{ method: :apply_score, unless_migration: :test_migration }] }.freeze)
        end
      end

      context 'when migration has finished' do
        before do
          allow(::Elastic::DataMigrationService)
            .to receive(:migration_has_finished?)
            .with(:test_migration)
            .and_return(true)
        end

        it 'skips the score component' do
          expect(score_module).not_to receive(:apply_score)
          builder.build
        end
      end

      context 'when migration has not finished' do
        before do
          allow(::Elastic::DataMigrationService)
            .to receive(:migration_has_finished?)
            .with(:test_migration)
            .and_return(false)
        end

        it 'applies the score component' do
          expect(score_module).to receive(:apply_score)
          builder.build
        end
      end
    end
  end
end
