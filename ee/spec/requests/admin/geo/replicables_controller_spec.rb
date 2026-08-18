# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Geo::ReplicablesController, :geo, feature_category: :geo_replication do
  include AdminModeHelper
  include EE::GeoHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:primary_node) { create(:geo_node) }
  let_it_be(:secondary_node) { create(:geo_node, :secondary) }

  let(:replicable_class) { Gitlab::Geo.replication_enabled_replicator_classes.sample }

  before do
    enable_admin_mode!(admin)
    login_as(admin)
  end

  subject do
    get url
    response
  end

  shared_examples 'license required' do
    context 'without a valid license' do
      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end
  end

  describe 'GET /admin/geo/replicables/:replicable_name_plural' do
    let(:url) { "/admin/geo/replication/#{replicable_class.replicable_name_plural}" }

    it_behaves_like 'license required'

    context 'with a valid license' do
      before do
        stub_licensed_features(geo: true)

        get url
      end

      context 'when Geo is not enabled' do
        it { is_expected.to redirect_to(admin_geo_nodes_path) }
      end

      context 'when on a Geo primary' do
        before do
          stub_primary_node
        end

        it { is_expected.to redirect_to(admin_geo_nodes_path) }
      end

      context 'when on a Geo secondary' do
        before do
          stub_current_geo_node(secondary_node)
        end

        it do
          is_expected.to redirect_to(
            site_replicables_admin_geo_node_path(id: secondary_node.id, replicable_name_plural: replicable_class.replicable_name_plural)
          )
        end
      end
    end
  end

  describe 'GET /admin/geo/sites/:id/replicables/:replicable_name_plural' do
    let(:url) { "/admin/geo/sites/#{secondary_node.id}/replication/#{replicable_class.replicable_name_plural}" }

    it_behaves_like 'license required'

    context 'with a valid license' do
      before do
        stub_licensed_features(geo: true)
      end

      where(:current_node) { [nil, lazy { primary_node }, lazy { secondary_node }] }

      with_them do
        context 'loads node data' do
          before do
            stub_current_geo_node(current_node) if current_node.present?
          end

          it { is_expected.not_to be_redirect }

          it 'includes expected current and target ids' do
            get url

            expect(response.body).to include("geo-target-site-id=\"#{secondary_node.id}\"")
            if current_node.present?
              expect(response.body).to include("geo-current-site-id=\"#{current_node&.id}\"")
            else
              expect(response.body).not_to include("geo-current-site-id")
            end
          end
        end
      end
    end
  end

  describe 'GET /admin/geo/sites/:id/replicables/:replicable_name_plural/:replicable_id' do
    let(:base_url) { "/admin/geo/sites/#{secondary_node.id}/replication" }
    let(:url) do
      replicable_name = replicable_class.replicable_name_plural
      # rubocop:disable Rails/SaveBang -- This is not creating a record but a factory.
      # See Rubocop issue: https://github.com/thoughtbot/factory_bot/issues/1620
      model_record = create(factory_name(replicable_class.model))
      # rubocop:enable Rails/SaveBang

      "#{base_url}/#{replicable_name}/#{model_record.id}"
    end

    it_behaves_like 'license required'

    context 'with a valid license' do
      before do
        stub_licensed_features(geo: true)
      end

      where(:current_node) { [nil, lazy { primary_node }, lazy { secondary_node }] }

      with_them do
        context 'valid replicable params' do
          it 'renders show template' do
            get url

            expect(response).to render_template :show
          end
        end

        context 'invalid replicable id' do
          it 'renders 404' do
            get "#{base_url}/#{replicable_class.replicable_name_plural}/invalid_id"

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'invalid replicable_name' do
          it 'renders 404' do
            get "#{base_url}/invalid_names/1"

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end
    end
  end
end
