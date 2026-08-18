# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/data_management/show.html.haml', :enable_admin_mode, feature_category: :geo_replication do
  let_it_be(:model) { build_stubbed(:project) }

  before do
    allow(view).to receive(:page_title)
    allow(view).to receive(:add_to_breadcrumbs)
    allow(view).to receive(:breadcrumb_title)

    assign(:model, model)

    render
  end

  it 'sets page title' do
    expect(view).to have_received(:page_title).with("Project/#{model.id}")
  end

  it 'sets breadcrumbs' do
    expect(view).to have_received(:breadcrumb_title).with(model.id.to_s)
    expect(view).to have_received(:add_to_breadcrumbs)
      .with('Projects', "#{admin_data_management_path}/projects")
    expect(view).to have_received(:add_to_breadcrumbs)
      .with(_('Data management'), admin_data_management_path)
  end

  it 'renders #js-admin-data-management-item' do
    expect(rendered).to have_selector('#js-admin-data-management-item')
  end
end
