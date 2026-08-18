# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GoogleCloud::Compute::ListRegionsService, feature_category: :fleet_visibility do
  using RSpec::Parameterized::TableSyntax
  include_context 'for a compute service'

  describe '#execute' do
    let(:filter) { 'name=test' }
    let(:max_results) { 50 }
    let(:page_token) { 'token' }
    let(:order_by) { 'name asc' }
    let(:params) do
      {
        google_cloud_project_id: google_cloud_project_id, filter: filter,
        max_results: max_results, page_token: page_token, order_by: order_by
      }.compact
    end

    subject(:response) { service.execute }

    it_behaves_like 'a compute service handling validation errors', client_method: :regions

    context 'with saas only feature enabled' do
      let(:google_cloud_support) { true }

      before do
        allow(client_double).to receive(:regions)
          .with(filter: filter, max_results: max_results, page_token: page_token, order_by: order_by)
          .and_return(dummy_list_response)
      end

      it 'returns the regions' do
        expect(response).to be_success
        expect(response.payload[:items]).to be_a Enumerable
        expect(response.payload[:items]).to contain_exactly({ name: 'test', description: 'us-central1' })
        expect(response.payload[:next_page_token]).to eq('next_page_token')
      end

      it_behaves_like 'overriding the google cloud project id'

      context 'with an invalid order_by' do
        where(:field, :direction) do
          'test' | 'asc'
          'name' | 'greater_than'
          ''     | 'desc'
          'name' | ''
        end

        with_them do
          let(:order_by) { "#{field} #{direction}" }

          it_behaves_like 'returning an error service response', message: 'Invalid order_by value'
        end

        context 'with an invalid max_results' do
          where(:max_results) { [0, described_class::MAX_RESULTS_LIMIT + 1] }

          with_them do
            it_behaves_like 'returning an error service response', message: 'Max results argument is out-of-bounds'
          end
        end
      end
    end

    private

    def dummy_list_response
      ::Google::Cloud::Compute::V1::RegionList.new(
        items: [::Google::Cloud::Compute::V1::Region.new(name: 'test', description: 'us-central1')],
        next_page_token: 'next_page_token'
      )
    end
  end
end
