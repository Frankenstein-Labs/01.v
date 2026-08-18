# frozen_string_literal: true

require "spec_helper"

RSpec.describe Geo::Console::ShowPrimaryChecksumFailuresForReplicatorClassAction, feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:action) do
    described_class.new(
      replicator_class: Geo::PagesDeploymentReplicator,
      input_stream: input_stream,
      output_stream: output_stream)
  end

  let(:input_stream) { StringIO.new("50\n") }
  let(:output_stream) { StringIO.new }

  describe "#open" do
    # freeze: true prevents accidental mutation of shared test data
    let_it_be(:current_node, freeze: true) { create(:geo_node, primary: true, name: "Tokyo") }

    before do
      stub_current_geo_node(current_node)
    end

    it_behaves_like "a Geo console action"

    it "prints primary checksum failures" do
      create(:pages_deployment, :verification_failed, verification_failure: "Foo")
      create(:pages_deployment, :verification_failed, verification_failure: "Bar")
      create(:pages_deployment, :verification_failed, verification_failure: "Foo")

      action.open

      expect(output_stream.string).to include("Total failed to checksum on the primary: 3")
      expect(output_stream.string).to match(/"Foo"\s*=>\s*2,/)
      expect(output_stream.string).to match(/"Bar"\s*=>\s*1/)
    end
  end
end
