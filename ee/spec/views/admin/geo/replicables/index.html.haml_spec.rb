# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "admin/geo/replicables/index", feature_category: :geo_replication do
  include EE::GeoHelpers

  let_it_be(:user) { build_stubbed(:admin) }

  before do
    @replicator_class = Gitlab::Geo.replication_enabled_replicator_classes[0]
    @target_node = instance_double(GeoNode, id: 123, name: 'geo-test-node')
    allow(view).to receive(:current_user).and_return(user)

    render
  end

  it 'renders #js-geo-replicable' do
    expect(rendered).to have_css('#js-geo-replicable')
  end
end
