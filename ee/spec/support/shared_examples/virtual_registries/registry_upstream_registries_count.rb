# frozen_string_literal: true

# rubocop:disable Rails/SaveBang -- return value will be used
RSpec.shared_examples 'registry upstream registries count' do
  |upstream_factory:, registry_factory:, registry_upstream_factory:|

  describe '.registries_count_by_upstream_ids' do
    let_it_be(:upstream1, freeze: false) { create(upstream_factory) }
    let_it_be(:upstream2, freeze: false) { create(upstream_factory) }
    let_it_be(:upstream3, freeze: false) { create(upstream_factory) }

    let_it_be(:registry1, freeze: false) { create(registry_factory) }
    let_it_be(:registry2, freeze: false) { create(registry_factory) }

    let_it_be(:registry_upstream1, freeze: false) do
      create(registry_upstream_factory, registry: registry1, upstream: upstream1)
    end

    let_it_be(:registry_upstream2, freeze: false) do
      create(registry_upstream_factory, registry: registry2, upstream: upstream1)
    end

    let_it_be(:registry_upstream3, freeze: false) do
      create(registry_upstream_factory, registry: registry1, upstream: upstream2)
    end

    it 'returns count of registries grouped by upstream_id' do
      result = described_class.registries_count_by_upstream_ids([upstream1.id, upstream2.id, upstream3.id])

      expect(result).to eq(upstream1.id => 3, upstream2.id => 2, upstream3.id => 1)
    end

    it 'returns empty hash when no upstream_ids match' do
      result = described_class.registries_count_by_upstream_ids([999])

      expect(result).to eq({})
    end

    it 'returns empty hash when upstream_ids array is empty' do
      result = described_class.registries_count_by_upstream_ids([])

      expect(result).to eq({})
    end
  end
end
# rubocop:enable Rails/SaveBang -- return value will be used
