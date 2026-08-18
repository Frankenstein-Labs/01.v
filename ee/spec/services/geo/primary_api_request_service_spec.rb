# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PrimaryApiRequestService, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  subject(:request) { described_class.new('path/to_api', Net::HTTP::Get) }

  let_it_be(:primary_node, freeze: true) { create(:geo_node, :primary) }
  let_it_be(:geo_node, freeze: true) { create(:geo_node) }

  before do
    stub_current_geo_node(geo_node)
    stub_request(:get, primary_node.api_url('path/to_api'))
         .with(
           headers: {
             'User-Agent' => 'Ruby'
           })
         .to_return(status: 200, body: "foo", headers: {})
  end

  it 'returns the expected response' do
    expect(request.execute).to eq('foo')
  end
end
