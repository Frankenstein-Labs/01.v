# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::VirtualRegistries::Packages::Maven::CreateRegistryService, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let(:params) { { name: "Registry #{SecureRandom.hex(8)}", description: 'Test registry' } }
  let(:available) { true }

  describe '#execute' do
    subject(:result) { described_class.new(group: group, current_user: current_user, params: params).execute }

    before do
      allow(::VirtualRegistries::Packages::Maven).to receive(:virtual_registry_available?)
        .with(group, current_user).and_return(available)
    end

    it 'creates a registry successfully' do
      expect { result }.to change {
        ::VirtualRegistries::Packages::Maven::Registry.where(group: group).count
      }.from(0).to(1)
    end

    it 'returns a success response with the registry' do
      expect(result.status).to eq(:success)
      expect(result.payload).to have_attributes(
        group_id: group.id,
        name: params[:name],
        description: 'Test registry'
      )
    end

    context 'when virtual registry is not available' do
      let(:available) { false }

      it 'returns an error response' do
        expect(result.status).to eq(:error)
        expect(result.message).to include('Maven virtual registry not available')
      end

      it 'does not create a registry' do
        expect { result }.not_to change {
          VirtualRegistries::Packages::Maven::Registry.where(group: group).count
        }
      end
    end

    context 'with invalid parameters' do
      let(:params) { { name: '', description: 'Test registry' } }

      it 'fails to create a registry' do
        expect(result.status).to eq(:error)
      end

      it 'returns validation error messages' do
        expect(result.message).to include("Name can't be blank")
      end

      it 'does not persist the registry' do
        expect { result }.not_to change {
          VirtualRegistries::Packages::Maven::Registry.where(group: group).count
        }
      end
    end

    context 'when max registries per group is reached' do
      before_all do
        create_list(:virtual_registries_packages_maven_registry,
          VirtualRegistries::Packages::Maven::Registry::MAX_REGISTRY_COUNT,
          group: group)
      end

      it 'fails to create a registry' do
        expect(result.status).to eq(:error)
      end

      it 'returns max registry error message' do
        expect(result.message[0]).to include('20 registries is the maximum allowed per top-level group.')
      end

      it 'does not create another registry' do
        expect { result }.not_to change {
          VirtualRegistries::Packages::Maven::Registry.where(group: group).count
        }
      end
    end
  end
end
