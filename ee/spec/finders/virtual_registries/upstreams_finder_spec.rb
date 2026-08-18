# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::VirtualRegistries::UpstreamsFinder, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group, :private) }

  shared_examples 'upstreams finder' do |upstream_class:, registry_factory:, upstream_factory:|
    let_it_be(:registry) { create(registry_factory, group:) }
    let_it_be(:upstreams) { create_list(upstream_factory, 2, registries: [registry]) }
    let_it_be(:other_upstream) { create(upstream_factory) } # rubocop:disable Rails/SaveBang -- this is a factory

    describe '#execute' do
      let(:params) { {} }

      subject(:find_upstreams) { described_class.new(upstream_class:, group:, params:).execute }

      it { is_expected.to match_array(upstreams).and be_a(ActiveRecord::Relation) }

      context 'with upstream_name' do
        let(:params) { { upstream_name: 'foo' } }

        let_it_be(:upstream1) do
          create(upstream_factory, registries: [registry], name: 'upstream-foo')
        end

        let_it_be(:upstream2) do
          create(upstream_factory, registries: [registry], name: 'upstream-bar')
        end

        it 'returns upstreams which match the given upstream_name' do
          expect(find_upstreams).to match_array([upstream1])
        end
      end
    end
  end

  describe 'Maven upstreams' do
    it_behaves_like 'upstreams finder',
      upstream_class: ::VirtualRegistries::Packages::Maven::Upstream,
      registry_factory: :virtual_registries_packages_maven_registry,
      upstream_factory: :virtual_registries_packages_maven_upstream
  end

  describe 'Container upstreams' do
    it_behaves_like 'upstreams finder',
      upstream_class: ::VirtualRegistries::Container::Upstream,
      registry_factory: :virtual_registries_container_registry,
      upstream_factory: :virtual_registries_container_upstream
  end
end
