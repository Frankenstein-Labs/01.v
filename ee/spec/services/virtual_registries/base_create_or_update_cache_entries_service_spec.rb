# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::BaseCreateOrUpdateCacheEntriesService, feature_category: :virtual_registry do
  let(:group) { build(:group) }
  let(:upstream) { build(:virtual_registries_packages_maven_upstream, group: group) }
  let(:user) { build(:user, owner_of: group) }

  let(:params) { {} }

  subject(:service) { described_class.new(upstream: upstream, current_user: user, params: params) }

  describe '#entry_class' do
    it 'raises NotImplementedError' do
      expect { service.entry_class }.to raise_error(NotImplementedError, /must implement entry_class/)
    end
  end
end
