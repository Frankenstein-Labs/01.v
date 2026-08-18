# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Maven virtual registries', feature_category: :virtual_registry do
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

  describe 'new page' do
    subject(:url) { new_group_virtual_registries_maven_registry_path(group) }

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

      it 'renders 404' do
        visit url

        expect(page).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is a group member' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'maven virtual registry is unavailable'

      it 'allows creation of new maven virtual registry', :aggregate_failures do
        visit url

        expect(page).to have_selector('h1', text: 'New maven virtual registry')
        fill_in 'Name', with: 'test maven registry'
        fill_in 'Description (optional)', with: 'This is a test maven registry'
        click_button 'Create registry'

        expect(page).to have_current_path(group_virtual_registries_maven_registry_path(group,
          ::VirtualRegistries::Packages::Maven::Registry.last))
        expect(page).to have_title('test maven registry')
        expect(page).to have_content('Maven virtual registry was created')
      end

      it 'shows error when virtual registry name is too long', :aggregate_failures do
        visit url

        expect(page).to have_selector('h1', text: 'New maven virtual registry')
        fill_in 'Name', with: 'test maven registry' * 20
        click_button 'Create registry'
        expect(page).to have_content('Name is too long (maximum is 255 characters)')
      end

      it 'passes accessibility tests', :js do
        visit url

        wait_for_requests

        expect(page).to be_axe_clean
      end
    end
  end

  describe 'edit page' do
    let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }

    subject(:url) { edit_group_virtual_registries_maven_registry_path(group, registry) }

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

      it 'renders 404' do
        visit url

        expect(page).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is a group member', :aggregate_failures do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'maven virtual registry is unavailable'

      it 'allows updating existing maven virtual registry' do
        visit url

        expect(page).to have_selector('h1', text: 'Edit registry')
        fill_in 'Name', with: 'test maven registry'
        fill_in 'Description (optional)', with: 'This is a test maven registry'
        click_button 'Save changes'

        expect(page).to have_current_path(group_virtual_registries_maven_registry_path(group, registry))
        expect(page).to have_title('test maven registry')
        expect(page).to have_content('Maven virtual registry was updated')
      end

      it 'shows error when virtual registry name is too long' do
        visit url

        fill_in 'Name', with: 'test maven registry' * 20
        click_button 'Save changes'

        expect(page).to have_content('Name is too long (maximum is 255 characters)')
      end

      it 'allows deletion', :js do
        visit url

        click_button 'Delete registry'
        within_modal do
          click_button('Delete')
        end

        expect(page).to have_current_path(group_virtual_registries_maven_registries_and_upstreams_path(group))
        expect(page).to have_content('Maven virtual registry was deleted')
      end

      it 'passes accessibility tests', :js do
        visit url

        wait_for_requests

        expect(page).to be_axe_clean
      end
    end
  end

  describe 'show page' do
    let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }

    subject(:url) { group_virtual_registries_maven_registry_path(group, registry) }

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

      context 'without existing upstream registry', :aggregate_failures, :js do
        it_behaves_like 'page is accessible'

        it 'renders page without actions to create/update' do
          visit url

          expect(page).to have_selector('h1', text: registry.name)
          expect(page).to have_text('No upstreams yet')
          expect(page).not_to have_button('Add upstream')

          expect(page).not_to have_link('Edit', href:
            edit_group_virtual_registries_maven_registry_path(group, registry))
        end
      end

      context 'with existing upstream registry', :aggregate_failures, :js do
        let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }

        it_behaves_like 'page is accessible'

        it 'renders page without actions to create/update' do
          visit url

          expect(page).not_to have_text('No upstreams yet')

          expect(page).to have_link(upstream.name, href: group_virtual_registries_maven_upstream_path(group, upstream))
          expect(page).not_to have_button('Add upstream')
          expect(page).not_to have_button('Clear all caches')
          expect(page).not_to have_button('Clear cache')
          expect(page).not_to have_button('Remove upstream')
          expect(page).not_to have_link('Edit upstream', href:
            edit_group_virtual_registries_maven_upstream_path(group, upstream))
        end
      end
    end

    context 'when user is maintainer' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'maven virtual registry is unavailable'

      context 'without existing upstream registry', :aggregate_failures, :js do
        it_behaves_like 'page is accessible'

        it 'renders page with actions to create/edit' do
          visit url

          expect(page).to have_button('Add upstream')

          expect(page).to have_link('Edit', href:
            edit_group_virtual_registries_maven_registry_path(group, registry))
        end

        describe 'create maven upstream registry form' do
          before do
            visit url
            click_button 'Add upstream'
          end

          it_behaves_like 'page is accessible'

          it 'can create maven upstream registry' do
            fill_in 'Name', with: 'test upstream'
            fill_in 'Upstream URL', with: 'https://gitlab.com'

            click_button 'Create upstream'

            expect(page).to have_link('test upstream')
          end
        end
      end

      context 'with existing upstream registry', :aggregate_failures, :js do
        let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }
        let_it_be(:registry1) do
          create(:virtual_registries_packages_maven_registry, group: group, name: 'test registry')
        end

        let_it_be(:upstream1) do
          create(:virtual_registries_packages_maven_upstream, registries: [registry1], name: 'test upstream')
        end

        it_behaves_like 'page is accessible'

        it 'renders page with actions to create/edit' do
          visit url

          expect(page).to have_link(upstream.name, href: group_virtual_registries_maven_upstream_path(group, upstream))
          expect(page).to have_button('Clear all caches')
          expect(page).to have_button('Clear cache')
          expect(page).to have_button('Remove upstream')
          expect(page).to have_link('Edit upstream', href:
            edit_group_virtual_registries_maven_upstream_path(group, upstream))
        end

        it 'clicking remove upstream button removes upstream from registry' do
          visit url

          click_button 'Remove upstream'

          expect(page).to have_text('No upstreams yet')
        end

        describe 'link maven upstream registry form' do
          before do
            visit url
            click_button 'Add upstream'
          end

          it_behaves_like 'page is accessible'

          it 'can link maven upstream registry' do
            click_button 'Link existing upstream'

            select_from_listbox 'test upstream', from: 'Select an upstream'

            click_button 'Add upstream'

            wait_for_requests

            expect(page).to have_link('test upstream',
              href: group_virtual_registries_maven_upstream_path(group, upstream1))
          end
        end
      end
    end
  end
end
