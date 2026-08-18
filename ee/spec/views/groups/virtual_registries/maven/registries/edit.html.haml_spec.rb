# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/virtual_registries/maven/registries/edit', feature_category: :virtual_registry do
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:maven_registry) { build_stubbed(:virtual_registries_packages_maven_registry, group: group) }
  let_it_be(:user) { build_stubbed(:user) }

  before do
    assign(:group, group)
    assign(:maven_registry, maven_registry)
    allow(view).to receive_messages(
      current_user: user,
      can?: false,
      can_destroy_virtual_registry?: false,
      delete_registry_modal_data: {}
    )
  end

  it 'renders the page heading' do
    render

    expect(rendered).to have_selector('h1', text: 'Edit registry')
  end

  it 'renders the form partial' do
    render

    expect(view).to render_template(partial: '_form')
  end

  it 'passes correct URL to form partial' do
    expected_url = group_virtual_registries_maven_registry_path(group, maven_registry)

    render

    expect(rendered).to have_selector("form[action='#{expected_url}']")
  end

  it 'passes correct cancel path to form partial' do
    expected_cancel_path = group_virtual_registries_maven_registry_path(group, maven_registry)

    render

    expect(rendered).to have_link('Cancel', href: expected_cancel_path)
  end

  context 'when user can destroy virtual registry' do
    before do
      allow(view).to receive_messages(
        can_destroy_virtual_registry?: true,
        delete_registry_modal_data: {
          path: '/path/to/delete',
          method: 'delete',
          modal_attributes: { title: 'Delete Maven registry' }
        }
      )
    end

    it 'renders delete button' do
      render

      expect(rendered).to have_button('Delete registry')
    end

    it 'configures delete button with modal data' do
      render

      expect(rendered).to have_selector('.js-confirm-modal-button')
    end
  end

  context 'when user cannot destroy virtual registry' do
    it 'does not render delete button' do
      render

      expect(rendered).not_to have_button('Delete registry')
    end
  end
end
