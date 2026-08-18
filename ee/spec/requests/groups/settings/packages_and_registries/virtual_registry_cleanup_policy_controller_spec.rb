# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::PackagesAndRegistries::VirtualRegistryCleanupPolicyController, feature_category: :virtual_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
    sign_in(user)
  end

  describe 'GET #index' do
    subject(:request) { get group_settings_packages_and_registries_virtual_registry_cleanup_policy_index_path(group) }

    context 'when user is not authorized' do
      it_behaves_like 'returning response status', :not_found
    end

    context 'when user is authorized' do
      before_all do
        group.add_owner(user)
      end

      it_behaves_like 'returning response status', :ok

      it 'renders template' do
        request

        expect(response).to render_template(:index)
      end

      context 'when both virtual registries are unavailable' do
        before do
          allow(::VirtualRegistries::Packages::Maven).to receive(:virtual_registry_available?).and_return(false)
          allow(::VirtualRegistries::Container).to receive(:virtual_registry_available?).and_return(false)
        end

        it_behaves_like 'returning response status', :not_found
      end

      context 'when only container virtual registry is available' do
        before do
          allow(::VirtualRegistries::Packages::Maven).to receive(:virtual_registry_available?).and_return(false)
          allow(::VirtualRegistries::Container).to receive(:virtual_registry_available?).and_return(true)
        end

        it_behaves_like 'returning response status', :ok
      end

      context 'when only maven virtual registry is available' do
        before do
          allow(::VirtualRegistries::Container).to receive(:virtual_registry_available?).and_return(false)
          allow(::VirtualRegistries::Packages::Maven).to receive(:virtual_registry_available?).and_return(true)
        end

        it_behaves_like 'returning response status', :ok
      end
    end
  end
end
