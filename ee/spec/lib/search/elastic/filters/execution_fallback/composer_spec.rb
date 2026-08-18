# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Filters::ExecutionFallback::Composer, feature_category: :global_search do
  composer = described_class

  let(:enrichment_a) do
    Class.new do
      extend composer

      def initialize(ids)
        @ids = ids
      end

      def filter_a(ids = @ids)
        ids.index_with(&:even?)
      end

      def normalize_filter(value)
        value.to_s.strip
      end

      fallback_filter :filter_a, method: :filter_a
    end
  end

  let(:enrichment_b) do
    Class.new do
      extend composer

      def initialize(ids)
        @ids = ids
      end

      def filter_b(ids = @ids)
        ids.index_with { |id| id > 5 }
      end

      def normalize_filter(value)
        value.upcase
      end

      fallback_filter :filter_b, method: :filter_b
    end
  end

  describe '.fallback_filter' do
    it 'stores enrichments in ENRICHMENTS constant' do
      expect(enrichment_a::ENRICHMENTS).to eq([enrichment_a])
      expect(enrichment_b::ENRICHMENTS).to eq([enrichment_b])
    end

    it 'freezes enrichments array' do
      expect(enrichment_a::ENRICHMENTS).to be_frozen
    end

    it 'defines class-level execution methods' do
      expect(enrichment_a.filter_a([1, 2, 3]))
        .to eq({ 1 => false, 2 => true, 3 => false })

      expect(enrichment_b.filter_b([4, 6]))
        .to eq({ 4 => false, 6 => true })
    end
  end

  describe '.normalize_filter' do
    it 'delegates to the enrichment normalize_filter if defined' do
      expect(enrichment_a.normalize_filter(' value '))
        .to eq('value')

      expect(enrichment_b.normalize_filter('value'))
        .to eq('VALUE')
    end

    context 'when normalization is not defined' do
      let(:klass) do
        Class.new do
          extend composer

          def initialize(ids)
            @ids = ids
          end

          def filter_a
            {}
          end

          fallback_filter :filter_a, method: :filter_a
        end
      end

      it 'does not respond to normalize_filter' do
        expect(klass.respond_to?(:normalize_filter)).to be(false)
      end
    end
  end

  context 'when two separate classes define identical filter names' do
    let(:klass_one) do
      Class.new do
        extend composer

        def initialize(ids)
          @ids = ids
        end

        def shared(ids = @ids)
          ids.index_with { |_id| :one }
        end

        fallback_filter :shared_filter, method: :shared
      end
    end

    let(:klass_two) do
      Class.new do
        extend composer

        def initialize(ids)
          @ids = ids
        end

        def shared(ids = @ids)
          ids.index_with { |_id| :two }
        end

        fallback_filter :shared_filter, method: :shared
      end
    end

    it 'keeps execution isolated per class' do
      expect(klass_one.shared_filter([1])).to eq({ 1 => :one })
      expect(klass_two.shared_filter([1])).to eq({ 1 => :two })
    end

    it 'does not leak ENRICHMENTS between classes' do
      expect(klass_one::ENRICHMENTS).to match_array([klass_one])
      expect(klass_two::ENRICHMENTS).to match_array([klass_two])
    end
  end

  context 'when registering the same filter twice' do
    it 'raises a duplicate registration error' do
      klass = Class.new do
        extend composer

        def initialize(ids); end
        def compute; end

        fallback_filter :filter_a, method: :compute
      end

      expect do
        klass.fallback_filter :filter_a, method: :compute
      end.to raise_error(ArgumentError, /Filter already registered: filter_a/)
    end
  end

  context 'when execution method does not exist' do
    let(:klass) do
      Class.new do
        extend composer

        def initialize(ids)
          @ids = ids
        end

        fallback_filter :filter_a, method: :missing
      end
    end

    it 'raises error when filter is executed' do
      expect do
        klass.filter_a([1, 2])
      end.to raise_error(ArgumentError, /Undefined instance method `missing`/)
    end
  end

  context 'when normalization method does not exist' do
    let(:klass) do
      Class.new do
        extend composer

        def initialize(ids)
          @ids = ids
        end

        def filter_a(ids = @ids)
          ids.index_with(&:even?)
        end

        fallback_filter :filter_a, method: :filter_a, normalize_with: :missing
      end
    end

    it 'raises error when normalize_filter is called' do
      expect do
        klass.normalize_filter('value')
      end.to raise_error(ArgumentError, /Undefined instance method `missing`/)
    end
  end

  context 'when fallback_filter is declared before method definition' do
    let(:klass) do
      Class.new do
        extend composer

        fallback_filter :filter_a

        def initialize(ids)
          @ids = ids
        end

        def perform_preload(ids = @ids)
          ids.index_with(&:odd?)
        end
      end
    end

    it 'works correctly' do
      expect(klass.filter_a([1, 2, 3])).to eq({ 1 => true, 2 => false, 3 => true })
    end
  end

  context 'when namespace registration' do
    context 'when class is namespaced' do
      let!(:klass) do
        stub_const('TestNamespace', Module.new)

        klass = Class.new do
          extend composer

          def initialize(ids)
            @ids = ids
          end

          def perform_preload(ids = @ids)
            ids.index_with(&:even?)
          end
        end

        TestNamespace.const_set(:NamespacedEnrichment, klass)

        klass.fallback_filter :namespaced_filter

        klass
      end

      it 'registers under the namespace module' do
        expect(TestNamespace::ENRICHMENTS).to match_array([klass])
      end
    end

    context 'when class is top-level' do
      let(:klass) do
        Class.new do
          extend composer

          def initialize(ids)
            @ids = ids
          end

          def perform_preload(ids = @ids)
            ids.index_with(&:even?)
          end

          fallback_filter :top_level_filter
        end
      end

      it 'registers under itself' do
        expect(klass::ENRICHMENTS).to match_array([klass])
      end
    end

    context 'when namespace override is provided' do
      before do
        stub_const('CustomRegistry', Module.new)
      end

      let(:klass) do
        Class.new do
          extend composer

          def initialize(ids)
            @ids = ids
          end

          def perform_preload(ids = @ids)
            ids.index_with(&:odd?)
          end

          fallback_filter :custom_filter, namespace: CustomRegistry
        end
      end

      it 'registers under the provided namespace' do
        klass
        expect(CustomRegistry::ENRICHMENTS).to match_array([klass])
      end
    end
  end

  context 'when multiple enrichments register under the same namespace' do
    before do
      stub_const('SharedNamespace', Module.new)
    end

    let!(:klass_one) do
      Class.new do
        extend composer

        def perform_preload
          {}
        end

        fallback_filter :filter_one, namespace: SharedNamespace
      end
    end

    let!(:klass_two) do
      Class.new do
        extend composer

        def perform_preload
          {}
        end

        fallback_filter :filter_two, namespace: SharedNamespace
      end
    end

    it 'appends to existing ENRICHMENTS constant' do
      expect(SharedNamespace::ENRICHMENTS).to match_array([klass_one, klass_two])
    end
  end

  context 'when the same enrichment is registered more than once in the same namespace' do
    before do
      stub_const('SharedNamespace', Module.new)
    end

    let(:klass) do
      Class.new do
        extend composer

        def perform_preload
          {}
        end

        fallback_filter :filter_one, namespace: SharedNamespace
      end
    end

    it 'does not duplicate the enrichment in ENRICHMENTS' do
      klass

      klass.fallback_filter :filter_two, namespace: SharedNamespace

      expect(SharedNamespace::ENRICHMENTS.count { |e| e == klass }).to eq(1)
    end
  end
end
