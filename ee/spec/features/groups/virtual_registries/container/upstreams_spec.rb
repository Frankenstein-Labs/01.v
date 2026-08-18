# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Container virtual registry upstreams', feature_category: :virtual_registry do
  include Spec::Support::Helpers::ModalHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_container_upstream, registries: [registry]) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(container_virtual_registry: true)
    sign_in(user)
  end

  describe 'edit page' do
    subject(:url) { edit_group_virtual_registries_container_upstream_path(group, upstream) }

    context 'when user is not group member' do
      it 'renders 404' do
        visit url

        expect(page).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is guest' do
      before_all do
        group.add_guest(user)
      end

      it 'does not allow editing upstream', :js do
        visit url

        expect(page).to have_current_path(/#{group_virtual_registries_container_upstreams_path(group)}/)
      end
    end

    context 'when user is a group member' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'container virtual registry is unavailable'

      describe 'behaviour', :aggregate_failures, :js do
        it 'allows updates to existing upstream' do
          visit url

          expect(page).to have_selector('h1', text: 'Edit upstream')
          fill_in 'Name', with: 'test upstream'
          fill_in 'Description (optional)', with: 'This is a test  upstream'
          fill_in 'Password (optional)', with: 'mypassword1234'
          click_button 'Save changes'

          expect(page).to have_current_path(/#{group_virtual_registries_container_upstream_path(group, upstream)}/)
          expect(page).to have_selector('h1', text: 'test upstream')
          expect(page).to have_content('Upstream test upstream was successfully updated.')
        end

        it 'shows error when virtual upstream name is too long' do
          visit url

          fill_in 'Name', with: 'test container registry' * 20
          fill_in 'Username (optional)', with: ''
          click_button 'Save changes'

          expect(page).to have_content('Name is too long (maximum is 255 characters)')
        end

        it 'passes accessibility tests' do
          visit url

          wait_for_requests

          expect(page).to be_axe_clean
        end
      end
    end
  end
end
