# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/data_management/index.html.haml', :enable_admin_mode, feature_category: :geo_replication do
  before do
    allow(view).to receive(:breadcrumb_title)
    allow(view).to receive(:page_title)
    allow(view).to receive(:admin_data_management_path).and_return('/admin/data_management')
    @model_class = Gitlab::Geo::ModelMapper.available_models.first

    render
  end

  it 'sets page title' do
    expect(view).to have_received(:page_title).with(_('Data management'))
  end

  it 'sets breadcrumbs' do
    expect(view).to have_received(:breadcrumb_title).with(_('Data management'))
  end

  it 'sets breadcrumb link' do
    expect(view.instance_variable_get(:@breadcrumb_link)).to eq('/admin/data_management')
  end

  it 'renders #js-admin-data-management' do
    expect(rendered).to have_selector('#js-admin-data-management')
  end
end
