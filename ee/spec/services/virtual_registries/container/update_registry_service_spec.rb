# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::VirtualRegistries::Container::UpdateRegistryService, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:registry) { create(:virtual_registries_container_registry, group: group) }

  let(:params) do
    {
      name: 'New name',
      description: 'New description'
    }
  end

  shared_examples 'unauthorized access' do
    it { is_expected.to be_error.and have_attributes(reason: :unauthorized, message: 'Unauthorized') }

    it 'does not update the registry name' do
      expect { result }.not_to change { registry.reload.name }
    end
  end

  describe '#execute' do
    subject(:result) { described_class.new(registry: registry, current_user: current_user, params: params).execute }

    before_all do
      group.add_owner(current_user)
    end

    it 'updates a registry name and description successfully' do
      expect { result }
        .to change { registry.reload.name }.to('New name')
        .and change { registry.description }.to('New description')
    end

    it { is_expected.to be_success.and have_attributes(payload: have_attributes(**params.merge(id: registry.id))) }

    context 'when user is not authorized' do
      let(:current_user) { build(:user) }

      it_behaves_like 'unauthorized access'
    end

    context 'when current_user is nil' do
      let(:current_user) { nil }

      it_behaves_like 'unauthorized access'
    end

    context 'with invalid parameters' do
      let(:params) { { name: nil, description: 'New description' } }

      it { is_expected.to be_error.and have_attributes(message: include("Name can't be blank")) }

      it 'does not update the registry name' do
        expect { result }.not_to change { registry.reload.name }
      end
    end

    context 'with no allowed parameters' do
      let(:params) { { group_id: non_existing_record_id } }

      it 'returns an invalid_params error response' do
        is_expected.to be_error.and have_attributes(reason: :invalid_params, message: 'Invalid parameters provided')
      end

      it 'does not update the registry' do
        expect { result }.not_to change { registry.reload.name }
      end
    end

    context 'with unallowed parameters' do
      let(:params) { super().merge(group_id: non_existing_record_id) }

      it 'updates a registry name and description successfully' do
        expect { result }
          .to change { registry.reload.name }.to('New name')
          .and change { registry.description }.to('New description')
      end

      it 'returns a success response with the registry' do
        is_expected.to be_success.and have_attributes(
          payload: have_attributes(**params.except(:group_id).merge(id: registry.id))
        )
      end

      it 'does not update the registry group id' do
        expect { result }.not_to change { registry.reload.group_id }
      end
    end
  end
end
