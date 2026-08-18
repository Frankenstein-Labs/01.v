# frozen_string_literal: true

require "spec_helper"

RSpec.describe Geo::Console::ShowSyncFailuresForReplicatorClassAction, feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:action) do
    described_class.new(
      replicator_class: Geo::UploadReplicator,
      input_stream: input_stream,
      output_stream: output_stream)
  end

  let(:input_stream) { StringIO.new("20\n") }
  let(:output_stream) { StringIO.new }

  describe "#open" do
    # freeze: true prevents accidental mutation of shared test data
    let_it_be(:current_node, freeze: true) { create(:geo_node, primary: false, name: "Tokyo") }

    before do
      stub_current_geo_node(current_node)
    end

    it_behaves_like "a Geo console action"

    it "prints sync failures" do
      create_list(:geo_upload_registry, 2, :failed, last_sync_failure: "Foo")
      create(:geo_upload_registry, :failed, last_sync_failure: "Bar")

      action.open

      expect(output_stream.string).to include("Total failed to sync: 3")
      expect(output_stream.string).to match(/"Foo"\s*=>\s*2,/)
      expect(output_stream.string).to match(/"Bar"\s*=>\s*1/)
    end
  end
end
