# frozen_string_literal: true

RSpec.shared_examples 'virtual registries: has exclusive upstreams' do |registry_factory:, upstream_factory:|
  # rubocop:disable Rails/SaveBang -- create! does not work here
  describe '#exclusive_upstreams' do
    let_it_be(:registry1, freeze: false) { create(registry_factory) }
    let_it_be(:registry2, freeze: false) { create(registry_factory) }
    let_it_be(:upstream1, freeze: false) { create(upstream_factory, registries: [registry1, registry2]) }
    let_it_be(:upstream2, freeze: false) { create(upstream_factory, registries: [registry1]) }

    subject { registry1.exclusive_upstreams }

    it { is_expected.to eq([upstream2]) }
  end
  # rubocop:enable Rails/SaveBang
end
