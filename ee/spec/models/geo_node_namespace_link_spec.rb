# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GeoNodeNamespaceLink, :models, feature_category: :geo_replication do
  describe 'relationships' do
    it { is_expected.to belong_to(:geo_node) }
    it { is_expected.to belong_to(:namespace) }
  end

  describe 'validations' do
    let!(:geo_node_namespace_link) { create(:geo_node_namespace_link) }

    it { is_expected.to validate_presence_of(:namespace_id) }
    it { is_expected.to validate_uniqueness_of(:namespace_id).scoped_to(:geo_node_id) }
  end

  context 'with loose foreign key on geo_node_namespace_links.namespace_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent, freeze: true) { create(:namespace) }
      let_it_be(:model, freeze: true) { create(:geo_node_namespace_link, namespace: parent) }
    end
  end
end
