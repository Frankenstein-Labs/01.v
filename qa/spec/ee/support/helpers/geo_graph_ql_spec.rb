# frozen_string_literal: true

module QA
  RSpec.describe QA::EE::Support::Helpers::GeoGraphQl do
    include described_class

    let(:api_client) { instance_double(QA::Runtime::API::Client) }

    describe '#fetch_secondary_node_id_from_api' do
      let(:request) { instance_double(QA::Runtime::API::Request, url: 'https://example.test/geo_nodes') }

      before do
        allow(QA::Runtime::API::Request).to receive(:new).with(api_client, '/geo_nodes').and_return(request)
        allow(QA::Runtime::Logger).to receive(:info)
        allow(QA::Runtime::Logger).to receive(:error)
      end

      context 'when the API request succeeds' do
        let(:response) { instance_double(RestClient::Response, code: 200, body: '{}') }

        before do
          allow(QA::Support::API).to receive(:get).with(request.url).and_return(response)
          allow(QA::Support::API).to receive(:success?).with(response.code).and_return(true)
          allow(QA::Support::API).to receive(:parse_body).with(response).and_return(nodes)
        end

        context 'and a secondary node is present' do
          let(:nodes) do
            [
              { id: 1, primary: true, name: 'primary' },
              { id: 2, primary: false, name: 'secondary' }
            ]
          end

          it 'returns the secondary node id' do
            expect(fetch_secondary_node_id_from_api(api_client)).to eq(2)
          end

          it 'logs the found secondary node' do
            fetch_secondary_node_id_from_api(api_client)

            expect(QA::Runtime::Logger).to have_received(:info)
              .with(a_string_including('id=2', 'name=secondary'))
          end
        end

        context 'and multiple secondary nodes are present' do
          let(:nodes) do
            [
              { id: 1, primary: true, name: 'primary' },
              { id: 2, primary: false, name: 'secondary-1' },
              { id: 3, primary: false, name: 'secondary-2' }
            ]
          end

          it 'returns the first secondary node id' do
            expect(fetch_secondary_node_id_from_api(api_client)).to eq(2)
          end
        end

        context 'and no secondary node is present' do
          let(:nodes) { [{ id: 1, primary: true, name: 'primary' }] }

          it 'returns nil' do
            expect(fetch_secondary_node_id_from_api(api_client)).to be_nil
          end

          it 'logs an error listing the available node names' do
            fetch_secondary_node_id_from_api(api_client)

            expect(QA::Runtime::Logger).to have_received(:error)
              .with(a_string_including('primary'))
          end
        end
      end

      context 'when the API request fails' do
        let(:response) { instance_double(RestClient::Response, code: 500, body: 'Internal Server Error') }

        before do
          allow(QA::Support::API).to receive(:get).with(request.url).and_return(response)
          allow(QA::Support::API).to receive(:success?).with(response.code).and_return(false)
        end

        it 'returns nil' do
          expect(fetch_secondary_node_id_from_api(api_client)).to be_nil
        end

        it 'logs an error including the response code' do
          fetch_secondary_node_id_from_api(api_client)

          expect(QA::Runtime::Logger).to have_received(:error)
            .with(a_string_including('500'))
        end

        it 'does not attempt to parse the response body' do
          expect(QA::Support::API).not_to receive(:parse_body)

          fetch_secondary_node_id_from_api(api_client)
        end
      end
    end
  end
end
