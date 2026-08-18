# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::VirtualRegistries::Container::DestroyRegistryUpstreamService, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_container_upstream, group: group) }
  let_it_be(:registry_upstream) { create(:virtual_registries_container_registry_upstream, registry:, upstream:) }
  let_it_be(:registry_upstream2) { create(:virtual_registries_container_registry_upstream, registry:) }
  let(:available) { true }

  describe '#execute' do
    subject(:result) do
      described_class.new(registry_upstream: registry_upstream, current_user: current_user).execute
    end

    before do
      allow(::VirtualRegistries::Container).to receive(:virtual_registry_available?)
        .with(group, current_user, :destroy_virtual_registry).and_return(available)
    end

    it 'destroys a registry upstream successfully' do
      expect { result }.to change {
        ::VirtualRegistries::Container::RegistryUpstream.count
      }.by(-1)
    end

    it 'syncs the positions' do
      expect { result }.to change { registry_upstream2.reload.position }.by(-1)
    end

    it 'returns a success response with the registry upstream' do
      expect(result.status).to eq(:success)
      expect(result.payload).to have_attributes(
        registry_id: registry.id,
        position: 1
      )
    end

    context 'when virtual registry is not available' do
      let(:available) { false }

      it 'returns an error response' do
        expect(result.status).to eq(:error)
        expect(result.message).to include('Unauthorized')
      end

      it 'does not create a registry upstream' do
        expect { result }.not_to change {
          ::VirtualRegistries::Container::RegistryUpstream.count
        }
      end
    end
  end
end
