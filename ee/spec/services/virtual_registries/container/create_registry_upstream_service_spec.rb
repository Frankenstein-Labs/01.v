# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::VirtualRegistries::Container::CreateRegistryUpstreamService, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_container_upstream, group: group) }
  let(:params) { { upstream: upstream } }
  let(:available) { true }

  describe '#execute' do
    subject(:result) { described_class.new(registry: registry, current_user: current_user, params: params).execute }

    before do
      allow(::VirtualRegistries::Container).to receive(:virtual_registry_available?)
        .with(group, current_user).and_return(available)
    end

    it 'creates a registry upstream successfully' do
      expect { result }.to change {
        ::VirtualRegistries::Container::RegistryUpstream.where(registry: registry).count
      }.from(0).to(1)
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
          ::VirtualRegistries::Container::RegistryUpstream.where(registry: registry).count
        }
      end
    end

    context 'when upstream is not part of the registries group' do
      let(:params) { { upstream: create(:virtual_registries_container_upstream, group: create(:group)) } }

      it 'fails to create a registry upstream' do
        expect(result.status).to eq(:error)
      end

      it 'returns validation error messages' do
        expect(result.message).to include("Not found")
      end

      it 'does not persist the registry upstream' do
        expect { result }.not_to change {
          ::VirtualRegistries::Container::RegistryUpstream.where(registry: registry).count
        }
      end
    end

    context 'when max upstreams per registry is reached' do
      before_all do
        create_list(:virtual_registries_container_registry_upstream,
          VirtualRegistries::Container::RegistryUpstream::MAX_UPSTREAMS_COUNT,
          registry: registry)
      end

      it 'fails to create a registry upstream' do
        expect(result.status).to eq(:error)
      end

      it 'returns max registry error message' do
        expect(result.message[0]).to include('Position must be less than or equal to 5')
      end

      it 'does not create another registry' do
        expect { result }.not_to change {
          ::VirtualRegistries::Container::RegistryUpstream.where(registry: registry).count
        }
      end
    end
  end
end
