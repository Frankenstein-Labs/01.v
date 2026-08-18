# frozen_string_literal: true

require "spec_helper"

RSpec.describe Geo::Console::ShowAllSiteStatusDataAction, feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:action) { described_class.new(input_stream: input_stream, output_stream: output_stream) }
  let(:input_stream) { StringIO.new }
  let(:output_stream) { StringIO.new }

  describe "#open" do
    # freeze: true prevents accidental mutation of shared test data
    let_it_be(:primary_node, freeze: true) { create(:geo_node, primary: true, name: "New York") }
    let_it_be(:secondary_node, freeze: true) { create(:geo_node, primary: false, name: "Tokyo") }

    before do
      stub_current_geo_node(current_node)

      create_list(:geo_node_status, 2)
    end

    context "when on a primary Geo node" do
      let(:current_node) { primary_node }

      it_behaves_like "a Geo console action"

      it "pretty prints GeoNodeStatus#all" do
        action.open

        expect(output_stream.string).to include("[#<GeoNodeStatus:")
        expect(output_stream.string).to include("  id: ")
      end
    end

    context "when on a secondary Geo node" do
      let(:current_node) { secondary_node }

      it_behaves_like "a Geo console action"

      it "pretty prints GeoNodeStatus#all" do
        action.open

        expect(output_stream.string).to include("[#<GeoNodeStatus:")
        expect(output_stream.string).to include("  id: ")
      end
    end
  end
end
