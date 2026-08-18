# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Console::Choice, feature_category: :geo_replication do
  include EE::GeoHelpers

  let_it_be(:primary_node, freeze: true) { create(:geo_node, primary: true, name: "New York") }
  let_it_be(:secondary_node, freeze: true) { create(:geo_node, name: "London") }
  let(:output_stream) { StringIO.new }

  context 'with an instance of the abstract Choice class' do
    let(:action) { described_class.new(output_stream: output_stream) }

    before do
      stub_current_geo_node(primary_node)
    end

    it "raises an error when #open is not implemented" do
      expect { action.open }.to raise_error(NotImplementedError, "#{described_class} must implement #open")
    end
  end

  describe '#header' do
    let(:action) { described_class.new(output_stream: output_stream) }

    before do
      allow(action).to receive(:name).and_return("Choice name")
    end

    context 'when on a primary node' do
      before do
        stub_current_geo_node(primary_node)
      end

      it 'includes "Geo Primary Site" with node name in the header' do
        expect(action.header).to include("Geo Primary Site | New York")
      end
    end

    context 'when on a secondary node' do
      before do
        stub_current_geo_node(secondary_node)
      end

      it 'includes "Geo Secondary Site" with node name in the header' do
        expect(action.header).to include("Geo Secondary Site | London")
      end
    end

    context 'when on an org migration target node' do
      before do
        stub_org_migration_target_cell(secondary_node)
      end

      it 'includes "Org Migration Target Cell" with node name in the header' do
        expect(action.header).to include("Org Migration Target Cell | London")
      end
    end
  end
end
