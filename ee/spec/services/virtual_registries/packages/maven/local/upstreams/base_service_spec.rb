# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::Local::Upstreams::BaseService, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }

  let(:params) { { name: 'test' } }
  let(:service) { described_class.new(container: registry, current_user: user, params: params) }

  subject(:execute) { service.execute }

  describe '#execute' do
    it 'raises NotImplementedError for allowed?' do
      expect { execute }.to raise_error(NotImplementedError, /must implement #allowed\?/)
    end

    context 'when allowed? is stubbed' do
      it 'raises NotImplementedError for process_upstream' do
        expect(service).to receive(:allowed?).and_return(true)
        expect { execute }.to raise_error(NotImplementedError, /must implement #process_upstream/)
      end
    end
  end
end
