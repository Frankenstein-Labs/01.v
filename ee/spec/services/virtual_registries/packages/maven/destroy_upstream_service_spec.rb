# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::VirtualRegistries::Packages::Maven::DestroyUpstreamService, feature_category: :virtual_registry do
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry) }
  let_it_be(:group) { registry.group }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }
  let(:available) { true }
  let(:service) { described_class.new(upstream: upstream, current_user: current_user) }

  before do
    allow(::VirtualRegistries::Packages::Maven).to receive(:virtual_registry_available?)
      .with(group, current_user, :destroy_virtual_registry).and_return(available)
  end

  describe '#execute' do
    subject(:result) { service.execute }

    it 'destroys the upstream' do
      result

      expect(upstream).to be_destroyed
      expect(result.status).to eq(:success)
    end

    it 'syncs registry upstream positions' do
      expect(::VirtualRegistries::Packages::Maven::RegistryUpstream).to receive(:sync_higher_positions)
        .with(upstream.registry_upstreams)
        .and_call_original

      result
    end

    context 'when user does not have permission' do
      let(:available) { false }

      it 'returns an error' do
        expect(result.message).to eq('Maven virtual registry not available')
        expect(result.status).to eq(:error)
        expect(result.reason).to eq(:unavailable)
      end
    end
  end
end
