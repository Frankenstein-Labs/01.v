# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/settings/roles_and_permissions/show', feature_category: :permissions do
  let_it_be(:role) { build(:member_role, id: 5, name: 'Custom role') }

  before do
    @member_role = role
    allow(view).to receive(:params).and_return(id: role.id)
    allow(view).to receive(:add_to_breadcrumbs)
    allow(view).to receive(:breadcrumb_title)
    allow(view).to receive(:page_title)
    allow(view).to receive(:group_settings_roles_and_permissions_path).and_return('list/path')

    render
  end

  it 'sets the breadcrumbs' do
    expect(view).to have_received(:add_to_breadcrumbs).with('Roles and permissions', 'list/path')
    expect(view).to have_received(:breadcrumb_title).with(role.name)
  end

  it 'sets the page title' do
    expect(view).to have_received(:page_title).with(role.name, 'Roles and permissions')
  end

  it 'renders frontend placeholder' do
    expect(rendered).to have_selector "#js-role-details[data-id='#{role.id}'][data-list-page-path='list/path']"
  end

  it 'renders the loading spinner' do
    expect(rendered).to have_selector '#js-role-details .gl-spinner'
  end
end
