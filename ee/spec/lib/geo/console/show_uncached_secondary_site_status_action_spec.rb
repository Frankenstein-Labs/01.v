# frozen_string_literal: true

require "spec_helper"

RSpec.describe Geo::Console::ShowUncachedSecondarySiteStatusAction, feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:action) { described_class.new(input_stream: input_stream, output_stream: output_stream) }
  let(:input_stream) { StringIO.new }
  let(:output_stream) { StringIO.new }

  describe "#open" do
    # freeze: true prevents accidental mutation of shared test data
    # it holds true for both because neither of them are mutated here
    let_it_be(:current_node, freeze: true) { create(:geo_node, primary: false, name: "Tokyo") }
    let_it_be(:status, freeze: true) { create(:geo_node_status, geo_node: current_node) }

    let(:check) { instance_double(Gitlab::Geo::GeoNodeStatusCheck) }

    before do
      stub_current_geo_node(current_node)

      allow(GeoNodeStatus).to receive(:current_node_status).and_return(status)
      allow(Gitlab::Geo::GeoNodeStatusCheck).to receive(:new).and_return(check)
      allow(check).to receive(:print_status)
    end

    it_behaves_like "a Geo console action"

    it "prints the status" do
      expect(check).to receive(:print_status)

      action.open
    end
  end
end
