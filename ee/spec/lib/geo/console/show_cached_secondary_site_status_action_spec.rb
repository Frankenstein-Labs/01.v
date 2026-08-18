# frozen_string_literal: true

require "spec_helper"

RSpec.describe Geo::Console::ShowCachedSecondarySiteStatusAction, feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:action) { described_class.new(input_stream: input_stream, output_stream: output_stream) }
  let(:input_stream) { StringIO.new }
  let(:output_stream) { StringIO.new }

  describe "#open" do
    # freeze: true prevents accidental mutation of shared test data
    # status uses let instead of let_it_be because update_cache! mutates the object in tests
    let_it_be(:current_node, freeze: true) { create(:geo_node, primary: false, name: "Tokyo") }
    let(:status) { create(:geo_node_status, geo_node: current_node) }

    before do
      stub_current_geo_node(current_node)
    end

    context "when status data is not cached" do
      it_behaves_like "a Geo console action"

      it "no-ops with a message" do
        action.open

        expect(output_stream.string).to include("No status data in cache")
      end
    end

    context "when status data is cached", :use_clean_rails_memory_store_caching do
      it "prints the status" do
        status.update_cache! # load cache

        # stubbing the final print_status because it does too much
        check = instance_double(Gitlab::Geo::GeoNodeStatusCheck)
        expect(Gitlab::Geo::GeoNodeStatusCheck).to receive(:new).and_return(check)
        expect(check).to receive(:print_status)

        action.open
      end
    end
  end
end
