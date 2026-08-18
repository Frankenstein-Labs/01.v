# frozen_string_literal: true

require "spec_helper"

RSpec.describe Sbom::ProcessVulnerabilitiesWorker, feature_category: :software_composition_analysis do
  describe "#handle_event" do
    let_it_be(:pipeline) { create(:ci_pipeline) }
    let(:id) { pipeline.id }
    let(:args) { { pipeline_id: id } }
    let(:sbom_ingest_event) { Sbom::SbomIngestedEvent.new(data: args) }

    it_behaves_like 'subscribes to event' do
      let(:event) { sbom_ingest_event }
    end

    it "calls Sbom::CreateVulnerabilitiesService" do
      expect(Sbom::CreateVulnerabilitiesService).to receive(:execute).with(id)

      described_class.new.handle_event(sbom_ingest_event)
    end
  end
end
