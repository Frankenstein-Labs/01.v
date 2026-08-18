# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Maven virtual registries and upstreams', :aggregate_failures, feature_category: :virtual_registry do
  include Spec::Support::Helpers::ModalHelpers
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
    sign_in(user)
  end

  shared_examples 'page is accessible' do
    it 'passes accessibility tests' do
      visit url
      wait_for_requests
      expect(page).to be_axe_clean
    end
  end

  describe 'list page' do
    subject(:url) { group_virtual_registries_maven_registries_and_upstreams_path(group) }

    context 'when user is not group member' do
      it 'renders 404' do
        visit url

        expect(page).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is a group member' do
      before_all do
        group.add_guest(user)
      end

      it_behaves_like 'maven virtual registry is unavailable'
    end

    context 'when user is maintainer' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'maven virtual registry is unavailable'
    end

    context 'with existing virtual registry', :js do
      let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, :with_upstreams, group: group) }
      let_it_be(:upstream) { registry.upstreams.first }

      context 'when user is a group member' do
        before_all do
          group.add_guest(user)
        end

        it_behaves_like 'page is accessible'

        it 'renders maven virtual registries tab without actions to create/edit' do
          visit url

          expect(page).to have_selector('h1', text: 'Maven virtual registries')
          expect(page).not_to have_link('Create registry',
            href: new_group_virtual_registries_maven_registry_path(group))

          expect(page).not_to have_link('Edit', href:
            edit_group_virtual_registries_maven_registry_path(group, registry))
          expect(page).to have_link(registry.name, href:
            group_virtual_registries_maven_registry_path(group, registry))
        end

        it 'renders upstreams tab without actions to create/edit' do
          visit_upstreams_tab

          expect(page).not_to have_link('Edit', href:
            edit_group_virtual_registries_maven_upstream_path(group, upstream))
          expect(page).to have_link(upstream.name, href:
            group_virtual_registries_maven_upstream_path(group, upstream))
        end
      end

      context 'when user is maintainer' do
        before_all do
          group.add_maintainer(user)
        end

        it_behaves_like 'page is accessible'

        it 'renders maven virtual registry page with actions to create/edit' do
          visit url

          expect(page).to have_selector('h1', text: 'Maven virtual registries')
          expect(page).to have_link('Create registry', href: new_group_virtual_registries_maven_registry_path(group))

          expect(page).to have_link('Edit', href:
            edit_group_virtual_registries_maven_registry_path(group, registry))
          expect(page).to have_link(registry.name, href:
            group_virtual_registries_maven_registry_path(group, registry))
        end

        it 'renders upstreams tab with actions to create/edit' do
          visit_upstreams_tab

          expect(page).to have_link('Edit', href:
            edit_group_virtual_registries_maven_upstream_path(group, upstream))
          expect(page).to have_link(upstream.name, href:
            group_virtual_registries_maven_upstream_path(group, upstream))
        end

        it 'allows deletion' do
          visit_upstreams_tab

          click_button 'More actions'
          click_button 'Delete upstream'

          within_modal do
            click_button 'Delete'
          end

          expect(page).to have_current_path(group_virtual_registries_maven_registries_and_upstreams_path(group,
            { tab: 'upstreams' }))
          expect(page).to have_content('Upstream has been deleted.')
          expect(page).to have_content('Upstreams 0')
        end
      end
    end
  end

  private

  def visit_upstreams_tab
    visit url
    wait_for_requests
    click_link 'Upstreams'
  end
end
