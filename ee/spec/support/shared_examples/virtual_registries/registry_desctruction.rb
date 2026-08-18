# frozen_string_literal: true

RSpec.shared_examples 'virtual registries: registry destruction' do
  |registry_factory:, upstream_factory:, registry_upstream_factory:, upstream_class:, registry_upstream_class:|
  describe 'registry destruction', :aggregate_failures do
    let_it_be_with_reload(:upstream) { create(upstream_factory) } # rubocop:disable Rails/SaveBang -- false positive

    let(:registry) { upstream.registries.first }

    subject(:destroy_registry) { registry.destroy! }

    it 'deletes the upstream and the registry_upstream' do
      expect { destroy_registry }.to change { described_class.count }.by(-1)
        .and change { upstream_class.count }.by(-1)
        .and change { registry_upstream_class.count }.by(-1)
    end

    context 'when the upstream is shared with another registry' do
      before_all do
        create(registry_factory, group: upstream.group, name: 'other').tap do |registry|
          create(registry_upstream_factory, registry:, upstream:)
        end
      end

      it 'does not delete the upstream' do
        expect { destroy_registry }.to change { described_class.count }.by(-1)
          .and change { registry_upstream_class.count }.by(-1)
          .and not_change { upstream_class.count }
      end
    end
  end
end
