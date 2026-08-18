# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::VirtualRegistries::DestroyRegistryUpstreamService, feature_category: :virtual_registry do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:registry_upstream) { create(:virtual_registries_container_registry_upstream) }

  let(:service) { described_class.new(registry_upstream: registry_upstream, current_user: current_user) }

  describe '#available?' do
    it 'raises NotImplementedError' do
      expect { service.send(:available?) }.to raise_error(NotImplementedError)
    end
  end
end
