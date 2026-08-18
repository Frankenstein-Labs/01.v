# frozen_string_literal: true

RSpec.shared_examples 'virtual registries: upstreams ordering' do |registry_factory:, upstream_factory:|
  describe 'upstreams ordering' do
    let_it_be(:registry, freeze: false) { create(registry_factory) } # rubocop:disable Rails/SaveBang -- false positive

    let_it_be(:upstream1, freeze: false) do
      create(upstream_factory, group: registry.group, registries: [registry])
    end

    let_it_be(:upstream2, freeze: false) do
      create(upstream_factory, group: registry.group, registries: [registry])
    end

    let_it_be(:upstream3, freeze: false) do
      create(upstream_factory, group: registry.group, registries: [registry])
    end

    subject { registry.reload.upstreams.to_a }

    it { is_expected.to eq([upstream1, upstream2, upstream3]) }
  end
end
