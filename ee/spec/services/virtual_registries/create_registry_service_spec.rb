# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::VirtualRegistries::CreateRegistryService, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let(:params) { {} }

  let(:service) { described_class.new(group: group, current_user: current_user, params: params) }

  describe '#unavailable_message' do
    it 'raises NotImplementedError' do
      expect { service.send(:unavailable_message) }.to raise_error(
        NotImplementedError,
        'Subclasses must implement #unavailable_message'
      )
    end
  end

  describe '#registry_class' do
    it 'raises NotImplementedError' do
      expect { service.send(:registry_class) }.to raise_error(
        NotImplementedError,
        'Subclasses must implement #registry_class'
      )
    end
  end

  describe '#availability_class' do
    it 'raises NotImplementedError' do
      expect { service.send(:availability_class) }.to raise_error(
        NotImplementedError,
        'Subclasses must implement #availability_class'
      )
    end
  end
end
