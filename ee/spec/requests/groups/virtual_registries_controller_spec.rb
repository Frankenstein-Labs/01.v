# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::VirtualRegistriesController, feature_category: :virtual_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true, container_virtual_registry: true)
  end

  describe 'GET #index' do
    subject(:api_request) { get group_virtual_registries_path(group) }

    it { is_expected.to have_request_urgency(:low) }

    context 'when user is not signed in' do
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed in' do
      before do
        sign_in(user)
      end

      context 'when user is not a group member' do
        it_behaves_like 'returning response status', :not_found
      end

      context 'when user is group member' do
        before_all do
          group.add_guest(user)
        end

        it_behaves_like 'returning response status', :ok

        it_behaves_like 'disallowed access to virtual registry'

        context 'when only maven virtual registry is available' do
          before do
            allow(::VirtualRegistries::Container).to receive(:virtual_registry_available?).and_return(false)
          end

          it_behaves_like 'returning response status', :ok
        end

        context 'when only container virtual registry is available' do
          before do
            allow(::VirtualRegistries::Packages::Maven).to receive(:virtual_registry_available?).and_return(false)
          end

          it_behaves_like 'returning response status', :ok
        end

        context 'when both virtual registries are unavailable' do
          before do
            allow(::VirtualRegistries::Packages::Maven).to receive(:virtual_registry_available?).and_return(false)
            allow(::VirtualRegistries::Container).to receive(:virtual_registry_available?).and_return(false)
          end

          it_behaves_like 'returning response status', :not_found
        end
      end
    end
  end
end
