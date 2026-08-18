# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Admin::Geo::NodesController, :geo, feature_category: :geo_replication do
  shared_examples 'unlicensed geo action' do
    it 'redirects to the 403 page' do
      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  let(:user) { create(:user) }
  let(:admin) { create(:admin) }

  before do
    sign_in(admin)
  end

  describe '#index' do
    render_views

    shared_examples 'no flash message' do |flash_type|
      it 'does not display a flash message' do
        go

        expect(flash).not_to include(flash_type)
      end
    end

    shared_examples 'with flash message' do |flash_type, message|
      it 'displays a flash message' do
        go

        expect(flash[flash_type]).to match(message)
      end
    end

    def go
      get :index
    end

    context 'with valid license' do
      before do
        allow(Gitlab::Geo).to receive(:license_allows?).and_return(true)
        go
      end

      it 'passes license_allows as true to the Vue component' do
        expect(response.body).to include('data-geo-license-allows="true"')
      end
    end

    context 'without valid license' do
      before do
        allow(Gitlab::Geo).to receive(:license_allows?).and_return(false)
        go
      end

      it 'passes license_allows as false to the Vue component' do
        expect(response.body).to include('data-geo-license-allows="false"')
      end

      it 'does not redirect to the 403 page' do
        expect(response).not_to redirect_to(:forbidden)
      end
    end
  end

  describe '#create' do
    let(:geo_node_attributes) { { url: 'http://example.com' } }

    def go
      post :create, params: { geo_node: geo_node_attributes }
    end

    context 'without add-on license' do
      before do
        allow(Gitlab::Geo).to receive(:license_allows?).and_return(false)
        go
      end

      it_behaves_like 'unlicensed geo action'
    end

    context 'with add-on license' do
      before do
        allow(Gitlab::Geo).to receive(:license_allows?).and_return(true)
      end

      it 'delegates the create of the Geo node to Geo::NodeCreateService' do
        expect_next_instance_of(Geo::NodeCreateService) do |instance|
          expect(instance).to receive(:execute).once.and_call_original
        end

        go
      end

      context 'when node creation is successful' do
        let(:geo_node_attributes) { { name: 'Test Node', url: 'http://example.com' } }

        it 'sets flash message and redirects to admin geo nodes path' do
          go

          expect(flash[:toast]).to eq('Node was successfully created.')
          expect(response).to redirect_to(admin_geo_nodes_path)
        end
      end

      context 'with organization_ids parameter' do
        let(:organization1) { create(:organization) }
        let(:organization2) { create(:organization) }
        let(:geo_node_attributes) { { url: 'http://example.com', organization_ids: [organization1.id.to_s, organization2.id.to_s] } }

        context 'when geo_selective_sync_by_organizations feature flag is enabled' do
          it 'includes organization_ids in the parameters passed to the service' do
            expected_params = ActionController::Parameters.new(geo_node_attributes).permit!

            expect(Geo::NodeCreateService).to receive(:new)
              .with(expected_params)
              .and_call_original

            go
          end
        end

        context 'when geo_selective_sync_by_organizations feature flag is disabled' do
          before do
            stub_feature_flags(geo_selective_sync_by_organizations: false)
          end

          it 'excludes organization_ids in the parameters passed to the service' do
            expected_params = geo_node_attributes.dup
            expected_params.delete(:organization_ids)
            expected_params = ActionController::Parameters.new(expected_params).permit!

            expect(Geo::NodeCreateService).to receive(:new)
              .with(expected_params)
              .and_call_original

            go
          end
        end
      end
    end
  end

  describe '#update' do
    let(:geo_node_attributes) do
      {
        url: 'http://example.com',
        internal_url: 'http://internal-url.com',
        selective_sync_shards: %w[foo bar]
      }
    end

    let(:geo_node) { create(:geo_node) }

    def go
      post :update, params: { id: geo_node, geo_node: geo_node_attributes }
    end

    context 'without add-on license' do
      before do
        allow(Gitlab::Geo).to receive(:license_allows?).and_return(false)
        go
      end

      it_behaves_like 'unlicensed geo action'
    end

    context 'with add-on license' do
      before do
        allow(Gitlab::Geo).to receive(:license_allows?).and_return(true)
      end

      it 'updates the node' do
        go

        geo_node.reload
        expect(geo_node.url.chomp('/')).to eq(geo_node_attributes[:url])
        expect(geo_node.internal_url.chomp('/')).to eq(geo_node_attributes[:internal_url])
        expect(geo_node.selective_sync_shards).to eq(%w[foo bar])
      end

      it 'delegates the update of the Geo node to Geo::NodeUpdateService' do
        expect_next_instance_of(Geo::NodeUpdateService) do |instance|
          expect(instance).to receive(:execute).once
        end

        go
      end

      context 'with organization_ids parameter' do
        let(:organization1) { create(:organization) }
        let(:organization2) { create(:organization) }
        let(:geo_node_attributes) do
          {
            url: 'http://example.com',
            internal_url: 'http://internal-url.com',
            selective_sync_shards: %w[foo bar],
            organization_ids: [organization1.id.to_s, organization2.id.to_s]
          }
        end

        context 'when geo_selective_sync_by_organizations feature flag is enabled' do
          it 'includes organization_ids in the parameters passed to the service' do
            expected_params = ActionController::Parameters.new(geo_node_attributes).permit!

            expect(Geo::NodeUpdateService).to receive(:new)
              .with(geo_node, expected_params)
              .and_call_original

            go
          end
        end

        context 'when geo_selective_sync_by_organizations feature flag is disabled' do
          before do
            stub_feature_flags(geo_selective_sync_by_organizations: false)
          end

          it 'excludes organization_ids in the parameters passed to the service' do
            expected_params = geo_node_attributes.dup
            expected_params.delete(:organization_ids)
            expected_params = ActionController::Parameters.new(expected_params).permit!

            expect(Geo::NodeUpdateService).to receive(:new)
              .with(geo_node, expected_params)
              .and_call_original

            go
          end
        end
      end
    end
  end
end
