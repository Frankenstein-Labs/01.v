# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::PackagesAndRegistriesController, feature_category: :package_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  before do
    stub_config(packages: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
    sign_in(user)
  end

  describe 'GET #show' do
    subject(:request) { get group_settings_packages_and_registries_path(group) }

    context 'when user is not authorized' do
      it_behaves_like 'returning response status', :not_found
    end

    context 'when user is authorized' do
      before_all do
        group.add_owner(user)
      end

      it_behaves_like 'returning response status', :ok

      context 'with shouldRenderVirtualRegistriesSetting' do
        it 'includes the setting as true in the dataset' do
          request

          expect(response.body).to include('data-should-render-virtual-registries-setting="true"')
        end

        context 'when maven_virtual_registry feature flag is disabled' do
          before do
            stub_feature_flags(maven_virtual_registry: false)
          end

          it 'includes the setting as false in the dataset' do
            request

            expect(response.body).to include('data-should-render-virtual-registries-setting="false"')
          end
        end

        context 'when licensed feature is not available' do
          before do
            stub_licensed_features(packages_virtual_registry: false)
          end

          it 'includes the setting as false in the dataset' do
            request

            expect(response.body).to include('data-should-render-virtual-registries-setting="false"')
          end
        end
      end
    end
  end
end
