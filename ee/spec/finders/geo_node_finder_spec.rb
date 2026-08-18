# frozen_string_literal: true

require 'spec_helper'

using RSpec::Parameterized::TableSyntax

RSpec.describe GeoNodeFinder, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let_it_be(:geo_node1, freeze: true) { create(:geo_node) }
  let_it_be(:geo_node2, freeze: true) { create(:geo_node) }
  let_it_be(:geo_node3, freeze: true) { create(:geo_node) }

  let(:params) { {} }

  subject(:geo_nodes) { described_class.new(user, params).execute }

  describe '#execute' do
    context 'when user cannot read all Geo' do
      let_it_be(:user, freeze: true) { create(:user) }

      it { is_expected.to be_empty }
    end

    context 'when user can read all Geo', :enable_admin_mode do
      let_it_be(:user, freeze: true) { create(:user, :admin) }

      context 'filtered by ID' do
        context 'when multiple IDs are given' do
          let(:params) { { ids: [geo_node3.id, geo_node1.id] } }

          it 'returns specified Geo nodes' do
            expect(geo_nodes.to_a).to eq([geo_node1, geo_node3])
          end
        end

        context 'when a single ID is given' do
          let(:params) { { ids: [geo_node2.id] } }

          it 'returns specified Geo nodes' do
            expect(geo_nodes.to_a).to eq([geo_node2])
          end
        end

        context 'when an empty array is given' do
          let(:params) { { ids: [] } }

          it 'returns none' do
            expect(geo_nodes).to be_empty
          end
        end
      end

      context 'filtered by name' do
        context 'when multiple names are given' do
          let(:params) { { names: [geo_node3.name, geo_node1.name] } }

          it 'returns specified Geo nodes' do
            expect(geo_nodes.to_a).to eq([geo_node1, geo_node3])
          end
        end

        context 'when a single name is given' do
          let(:params) { { names: [geo_node2.name] } }

          it 'returns specified Geo nodes' do
            expect(geo_nodes.to_a).to eq([geo_node2])
          end
        end

        context 'with trailing slash variants' do
          where(:stored_name, :requested_name, :found) do
            'https://primary.com'  | 'https://primary.com'   | true
            'https://primary.com'  | 'https://primary.com/'  | true
            'https://primary.com/' | 'https://primary.com'   | true
            'https://primary.com/' | 'https://primary.com/'  | true
            'https://primary.com'  | 'https://secondary.com' | false
          end

          with_them do
            let!(:geo_node) { create(:geo_node, name: stored_name) }

            let(:params) { { names: [requested_name] } }

            it 'finds the node only when names match ignoring a trailing slash' do
              expect(geo_nodes.to_a).to eq(found ? [geo_node] : [])
            end
          end
        end

        context 'when names with and without a trailing slash both exist' do
          let_it_be(:geo_node_without_trailing_slash, freeze: true) do
            create(:geo_node, name: 'https://same-name.example.com')
          end

          let_it_be(:geo_node_with_trailing_slash, freeze: true) do
            create(:geo_node, name: 'https://same-name.example.com/')
          end

          context 'when the name without a trailing slash is requested' do
            let(:params) { { names: [geo_node_without_trailing_slash.name] } }

            it 'returns only the exact match' do
              expect(geo_nodes.to_a).to eq([geo_node_without_trailing_slash])
            end
          end

          context 'when the name with a trailing slash is requested' do
            let(:params) { { names: [geo_node_with_trailing_slash.name] } }

            it 'returns only the exact match' do
              expect(geo_nodes.to_a).to eq([geo_node_with_trailing_slash])
            end
          end

          context 'when another name requires a trailing-slash fallback' do
            let_it_be(:fallback_geo_node, freeze: true) do
              create(:geo_node, name: 'https://fallback-name.example.com')
            end

            let(:params) do
              {
                names: [
                  geo_node_without_trailing_slash.name,
                  "#{fallback_geo_node.name}/"
                ]
              }
            end

            it 'uses the fallback only for the name without an exact match' do
              expect(geo_nodes).to match_array([geo_node_without_trailing_slash, fallback_geo_node])
            end
          end
        end

        context 'when an empty array is given' do
          let(:params) { { names: [] } }

          it 'returns none' do
            expect(geo_nodes).to be_empty
          end
        end
      end

      context 'not filtered by ID or name' do
        it 'returns all Geo nodes' do
          expect(geo_nodes.to_a).to eq([geo_node1, geo_node2, geo_node3])
        end
      end
    end
  end
end
