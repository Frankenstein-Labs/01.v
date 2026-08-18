# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::CleanupService do
  include ::EE::GeoHelpers

  let_it_be_with_reload(:project) { create(:project, :repository, bfg_object_map: fixture_file_upload('spec/fixtures/bfg_object_map.txt')) }
  let_it_be(:object_map, freeze: false) { project.bfg_object_map }
  let_it_be(:primary) { create(:geo_node, :primary) }

  subject(:service) { described_class.new(project) }

  describe '#execute' do
    before do
      stub_current_geo_node(primary)
      stub_feature_flags(geo_project_repository_replication_v2: false)

      create(:geo_node, :secondary)
    end

    it 'creates a new Geo event about the update on success' do
      expect do
        service.execute
      end.to change { Geo::Event.where(replicable_name: 'project_repository').count }.by(1)
    end

    it 'does not create a Geo event if the update fails' do
      object_map.remove!

      expect { service.execute }.to raise_error(/object map/)

      expect(Geo::Event.where(replicable_name: 'project_repository').count).to eq(0)
    end
  end
end
