# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::GeoNodeOrganizationLink, :models, feature_category: :geo_replication do
  describe 'relationships' do
    it { is_expected.to belong_to(:geo_node).required }
    it { is_expected.to belong_to(:organization).class_name('Organizations::Organization').required }
  end

  describe 'validations' do
    let!(:geo_node_organization_link) { create(:geo_node_organization_link) }

    it { is_expected.to validate_uniqueness_of(:organization_id).scoped_to(:geo_node_id) }
  end

  context 'with loose foreign key on geo_node_organization_links.organization_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent, freeze: true) { create(:organization) }
      let_it_be(:model, freeze: true) { create(:geo_node_organization_link, organization: parent) }
    end
  end
end
