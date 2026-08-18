# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::VirtualRegistries::Packages::Maven::DestroyRegistryUpstreamService,
  feature_category: :virtual_registry do
  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
  let_it_be_with_reload(:upstream1) do
    create(:virtual_registries_packages_maven_upstream, group: group, registries: [registry])
  end

  let_it_be_with_reload(:upstream2) do
    create(:virtual_registries_packages_maven_upstream, group: group, registries: [registry])
  end

  let_it_be_with_reload(:registry_upstream1) do
    VirtualRegistries::Packages::Maven::RegistryUpstream.find_by(registry: registry, upstream: upstream1)
  end

  let_it_be_with_reload(:registry_upstream2) do
    VirtualRegistries::Packages::Maven::RegistryUpstream.find_by(registry: registry, upstream: upstream2)
  end

  let(:available) { true }

  describe '#execute' do
    subject(:result) do
      described_class.new(registry_upstream: registry_upstream1, current_user: current_user).execute
    end

    before do
      allow(::VirtualRegistries::Packages::Maven).to receive(:virtual_registry_available?)
        .with(group, current_user, :destroy_virtual_registry).and_return(available)
    end

    it 'destroys the registry upstream successfully' do
      expect { result }.to change {
        ::VirtualRegistries::Packages::Maven::RegistryUpstream.where(registry: registry).count
      }.from(2).to(1)
    end

    it 'returns a success response with the registry upstream' do
      expect(result.status).to eq(:success)
      expect(result.payload).to be_destroyed
    end

    it 'syncs higher positions' do
      expect { result }.to change { registry_upstream2.reload.position }.from(2).to(1)
    end

    context 'when virtual registry is not available' do
      let(:available) { false }

      it 'returns an error response' do
        expect(result.status).to eq(:error)
        expect(result.message).to include('Unauthorized')
      end

      it 'does not destroy the registry upstream' do
        expect { result }.not_to change {
          ::VirtualRegistries::Packages::Maven::RegistryUpstream.where(registry: registry).count
        }
      end
    end
  end
end
