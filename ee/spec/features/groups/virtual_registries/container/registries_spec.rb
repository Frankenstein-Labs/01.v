# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Container virtual registries', feature_category: :virtual_registry do
  include Spec::Support::Helpers::ModalHelpers
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(container_virtual_registry: true)
    sign_in(user)
  end

  shared_examples 'page is accessible' do
    it 'passes accessibility tests' do
      visit url
      wait_for_requests
      expect(page).to be_axe_clean
    end
  end

  describe 'show page' do
    let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }

    subject(:url) { group_virtual_registries_container_registry_path(group, registry) }

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

      it_behaves_like 'container virtual registry is unavailable'

      context 'without existing upstream registry', :aggregate_failures, :js do
        it_behaves_like 'page is accessible'

        it 'renders page without actions to create/update' do
          visit url

          expect(page).to have_selector('h1', text: registry.name)
          expect(page).to have_text('No upstreams yet')
          expect(page).not_to have_button('Add upstream')

          expect(page).not_to have_link('Edit', href:
            edit_group_virtual_registries_container_registry_path(group, registry))
        end
      end

      context 'with existing upstream registry', :aggregate_failures, :js do
        let_it_be(:upstream) { create(:virtual_registries_container_upstream, registries: [registry]) }

        it_behaves_like 'page is accessible'

        it 'renders page without actions to create/update' do
          visit url

          expect(page).not_to have_text('No upstreams yet')

          expect(page).to have_link(upstream.name,
            href: /#{group_virtual_registries_container_upstream_path(group, upstream)}/)
          expect(page).not_to have_button('Add upstream')
          expect(page).not_to have_button('Clear all caches')
          expect(page).not_to have_button('Clear cache')
          expect(page).not_to have_button('Remove upstream')
          expect(page).not_to have_link('Edit upstream', href:
            edit_group_virtual_registries_container_upstream_path(group, upstream))
        end
      end
    end

    context 'when user is maintainer' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'container virtual registry is unavailable'

      context 'without existing upstream registry', :aggregate_failures, :js do
        it_behaves_like 'page is accessible'

        it 'renders page with actions to create/edit' do
          visit url

          expect(page).to have_button('Add upstream')

          expect(page).to have_link('Edit', href:
            edit_group_virtual_registries_container_registry_path(group, registry))
        end
      end

      context 'with existing upstream registry', :aggregate_failures, :js do
        let_it_be(:upstream) { create(:virtual_registries_container_upstream, registries: [registry]) }
        let_it_be(:registry1) do
          create(:virtual_registries_container_registry, group: group, name: 'test registry')
        end

        let_it_be(:upstream1) do
          create(:virtual_registries_container_upstream, registries: [registry1], name: 'test upstream')
        end

        it_behaves_like 'page is accessible'

        it 'renders page with actions to create/edit' do
          visit url

          expect(page).to have_link(upstream.name,
            href: /#{group_virtual_registries_container_upstream_path(group, upstream)}/)
          expect(page).to have_button('Clear all caches')
          expect(page).to have_button('Clear cache')
        end
      end
    end
  end
end
