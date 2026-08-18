# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::VirtualRegistries::CreateRegistryUpstreamService, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let(:params) { {} }

  let(:service) { described_class.new(registry: registry, current_user: current_user, params: params) }

  describe '#registry_upstream_class' do
    it 'raises NotImplementedError' do
      expect { service.send(:registry_upstream_class) }.to raise_error(NotImplementedError)
    end
  end

  describe '#available?' do
    it 'raises NotImplementedError' do
      expect { service.send(:available?) }.to raise_error(NotImplementedError)
    end
  end
end
