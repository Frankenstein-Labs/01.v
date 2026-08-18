# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Geo::GeoNodeResolver, feature_category: :geo_replication do
  include GraphqlHelpers
  include EE::GeoHelpers

  describe '#resolve' do
    let_it_be(:primary, freeze: true) { create(:geo_node, :primary) }
    let_it_be(:secondary, freeze: true) { create(:geo_node) }
    let_it_be(:user, freeze: true) { create(:user, :admin) }

    let(:gql_context) { { current_user: user } }

    context 'when the user has permission to view Geo data', :enable_admin_mode do
      context 'with a name' do
        context 'when the given name matches a node' do
          it 'returns the GeoNode' do
            expect(resolve_geo_node(name: primary.name)).to eq(primary)
            expect(resolve_geo_node(name: secondary.name)).to eq(secondary)
          end
        end

        context 'when the given name differs only by a trailing slash' do
          context 'when the stored name does not have a trailing slash' do
            it 'returns the GeoNode' do
              expect(resolve_geo_node(name: "#{primary.name}/")).to eq(primary)
            end
          end

          context 'when the stored name has a trailing slash' do
            let_it_be(:geo_node_with_trailing_slash, freeze: true) do
              create(:geo_node, name: 'https://with-trailing-slash.example.com/')
            end

            it 'returns the GeoNode' do
              expect(resolve_geo_node(name: geo_node_with_trailing_slash.name.chomp('/')))
                .to eq(geo_node_with_trailing_slash)
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

          it 'returns the exact matches' do
            expect(resolve_geo_node(name: geo_node_without_trailing_slash.name))
              .to eq(geo_node_without_trailing_slash)
            expect(resolve_geo_node(name: geo_node_with_trailing_slash.name))
              .to eq(geo_node_with_trailing_slash)
          end
        end

        context 'when the given name does not match any node' do
          it 'returns nil' do
            expect(resolve_geo_node(name: 'a node by this name does not exist')).to be_nil
          end
        end
      end

      context 'without a name' do
        context 'when the GitLab instance has a current Geo node' do
          before do
            stub_current_geo_node(secondary)
            stub_current_node_name(secondary.name)
          end

          it 'returns the GeoNode' do
            expect(resolve_geo_node).to eq(secondary)
          end
        end

        context 'when the GitLab instance does not have a current Geo node' do
          it 'returns nil' do
            expect(resolve_geo_node).to be_nil
          end
        end
      end
    end

    context 'when the user does not have permission to view Geo data' do
      it 'returns nil' do
        expect(resolve_geo_node).to be_nil
      end
    end
  end

  def resolve_geo_node(args = {})
    resolve(described_class, obj: nil, args: args, ctx: gql_context)
  end
end
