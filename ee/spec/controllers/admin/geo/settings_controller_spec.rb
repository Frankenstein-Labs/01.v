# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Geo::SettingsController, :geo, feature_category: :geo_replication do
  include EE::GeoHelpers
  include StubENV

  let_it_be(:admin, freeze: true) { create(:admin) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
  end

  shared_examples 'license required' do
    context 'without a valid license' do
      it 'redirects to 403 page' do
        is_expected.to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe '#show' do
    before do
      sign_in(admin)
    end

    context 'without a valid license' do
      subject(:get_show) { get :show }

      render_views

      before do
        stub_licensed_features(geo: false)
      end

      it 'does not redirect to the 403 page' do
        expect(get_show).not_to redirect_to(:forbidden)
      end

      it 'shows license upgrade messaging' do
        expect(get_show.body).to include('Available only on GitLab Premium.')
      end
    end

    context 'with a valid license' do
      subject(:get_show) { get :show }

      render_views

      before do
        stub_licensed_features(geo: true)
      end

      it 'does not show license upgrade messaging' do
        expect(get_show.body).not_to include('Available only on GitLab Premium.')
      end
    end
  end

  describe '#update' do
    before do
      sign_in(admin)
    end

    String test_value = '1.0.0.0/0, ::/0'

    context 'with a valid license' do
      before do
        stub_licensed_features(geo: true)
        @request.env['HTTP_REFERER'] = admin_geo_settings_path
        patch :update, params: { application_setting: { geo_node_allowed_ips: test_value } }
      end

      it 'sets the geo node property in ApplicationSetting' do
        expect(ApplicationSetting.current.geo_node_allowed_ips).to eq(test_value)
      end

      it 'redirects the update to the referer' do
        expect(request).to redirect_to(admin_geo_settings_path)
      end
    end
  end
end
