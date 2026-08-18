# frozen_string_literal: true

module QA
  RSpec.describe 'Systems', :orchestrated, :geo, feature_category: :geo_replication do
    describe 'Geo Nodes API' do
      include Support::API

      # go to the primary and create a personal_access_token, which will be used
      # for accessing both the primary and secondary
      let(:personal_access_token) do
        Runtime::API::Client.as_admin.personal_access_token
      end

      let(:api_client) { Runtime::API::Client.new(node_type, personal_access_token: personal_access_token) }

      let(:nodes) do
        response = Support::API.get(api_endpoint('/geo_nodes'))
        parse_body(response)
      end

      let(:primary_node) { nodes.detect { |node| node[:primary] == true } }
      let(:secondary_node) { nodes.detect { |node| node[:primary] == false } }

      shared_examples 'retrieving configuration about Geo nodes' do
        it 'GET /geo_nodes' do
          response = Support::API.get(api_endpoint('/geo_nodes'))
          response_body = parse_body(response)

          expect(response.code).to eq(QA::Support::API::HTTP_STATUS_OK)
          expect(response_body.size).to be >= 2

          expect(response_body).to include(include(primary: true))

          response_body.each do |node|
            expect(!!node[:primary]).to eq node[:primary]
            expect(!!node[:current]).to eq node[:primary]
            expect(node[:files_max_capacity]).to be_a(Integer)
            expect(node[:repos_max_capacity]).to be_a(Integer)
            expect(node[:clone_protocol]).to be_a(String)
            expect(node[:_links]).to be_a(Object)
          end
        end
      end

      shared_examples 'retrieving configuration about Geo nodes/:id' do
        it 'GET /geo_nodes/:id' do
          response = Support::API.get(api_endpoint("/geo_nodes/#{geo_node[:id]}"))
          response_body = parse_body(response)

          expect(response.code).to eq(QA::Support::API::HTTP_STATUS_OK)
          expect(response_body).to eq geo_node
        end
      end

      describe 'on primary node', :geo do
        let(:node_type) { :geo_primary }
        let(:geo_node) { primary_node }

        include_examples 'retrieving configuration about Geo nodes'
        include_examples 'retrieving configuration about Geo nodes/:id'

        describe 'editing a Geo node' do
          it 'PUT /geo_nodes/:id for secondary node' do
            endpoint = api_endpoint("/geo_nodes/#{secondary_node[:id]}")
            new_attributes = { enabled: false, files_max_capacity: 1000, repos_max_capacity: 2000 }

            response = Support::API.put(endpoint, new_attributes)
            response_body = parse_body(response)

            expect(response.code).to eq(QA::Support::API::HTTP_STATUS_OK)

            expect(response_body[:enabled]).to eq(false)
            expect(response_body[:files_max_capacity]).to eq(1000)
            expect(response_body[:repos_max_capacity]).to eq(2000)

            # restore the original values
            Support::API.put(endpoint, { enabled: secondary_node[:enabled],
                                         files_max_capacity: secondary_node[:files_max_capacity],
                                         repos_max_capacity: secondary_node[:repos_max_capacity] })

            expect(response.code).to eq(QA::Support::API::HTTP_STATUS_OK)
          end
        end
      end

      describe 'on secondary node', :geo do
        let(:node_type) { :geo_secondary }
        let(:geo_node) { nodes.first }

        include_examples 'retrieving configuration about Geo nodes'
        include_examples 'retrieving configuration about Geo nodes/:id'
      end

      def api_endpoint(endpoint)
        QA::Runtime::API::Request.new(api_client, endpoint).url
      end
    end
  end
end
