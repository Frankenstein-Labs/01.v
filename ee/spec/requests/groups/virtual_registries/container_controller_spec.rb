# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::VirtualRegistries::ContainerController, feature_category: :virtual_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(container_virtual_registry: true)
  end

  describe 'GET #index' do
    subject(:get_index) { get group_virtual_registries_container_path(group) }

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

        it_behaves_like 'disallowed access to container virtual registry'

        it 'pushes updateVirtualRegistry: false ability to frontend' do
          get_index

          expect(response.body).to have_pushed_frontend_ability(updateVirtualRegistry: false)
        end

        it 'pushes adminVirtualRegistry: false ability to frontend' do
          get_index

          expect(response.body).to have_pushed_frontend_ability(adminVirtualRegistry: false)
        end
      end

      context 'when user is group maintainer' do
        before_all do
          group.add_maintainer(user)
        end

        it 'pushes updateVirtualRegistry: true ability to frontend' do
          get_index

          expect(response.body).to have_pushed_frontend_ability(updateVirtualRegistry: true)
        end

        it 'pushes adminVirtualRegistry: false ability to frontend' do
          get_index

          expect(response.body).to have_pushed_frontend_ability(adminVirtualRegistry: false)
        end
      end

      context 'when user is group owner' do
        before_all do
          group.add_owner(user)
        end

        it 'pushes adminVirtualRegistry: true ability to frontend' do
          get_index

          expect(response.body).to have_pushed_frontend_ability(adminVirtualRegistry: true)
        end
      end
    end
  end
end
