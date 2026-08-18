# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::TransferRequest, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let(:geo_node) { create(:geo_node) }
  let(:request) { described_class.new }

  before do
    stub_current_geo_node(geo_node)
  end

  describe '#headers' do
    it 'includes the X-Sendfile-Type header' do
      expect(request.headers).to include('X-Sendfile-Type' => 'X-Sendfile')
    end

    it 'includes the Authorization header from parent class' do
      expect(request.headers['Authorization']).to start_with(Gitlab::Geo::BaseRequest::GITLAB_GEO_AUTH_TOKEN_TYPE)
    end

    it 'includes the X-Request-ID header with correlation ID' do
      correlation_id = 'test-correlation-id'
      allow(Labkit::Correlation::CorrelationId).to receive(:current_or_new_id).and_return(correlation_id)

      expect(request.headers['X-Request-ID']).to eq(correlation_id)
    end
  end
end
