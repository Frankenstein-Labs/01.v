# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/health_check/_health_check_url.html.haml', feature_category: :geo_replication do
  include EE::GeoHelpers

  context 'when on a Geo secondary node' do
    before do
      stub_secondary_node
    end

    it 'renders the Geo health check URL' do
      render partial: 'admin/health_check/health_check_url'

      token = Gitlab::CurrentSettings.health_check_access_token

      expect(rendered).to have_css('code', text: health_check_url(token: token, checks: :geo))
    end
  end

  context 'when not on a Geo secondary node' do
    it 'renders nothing' do
      render partial: 'admin/health_check/health_check_url'

      expect(rendered.strip).to be_empty
    end
  end
end
