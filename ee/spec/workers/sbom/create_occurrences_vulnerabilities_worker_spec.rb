# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::CreateOccurrencesVulnerabilitiesWorker, feature_category: :dependency_management do
  let(:event) { Sbom::VulnerabilitiesCreatedEvent.new(data: { findings: findings }) }
  let(:findings) do
    [
      {
        uuid: "uuid",
        project_id: 1,
        vulnerability_id: 1,
        pipeline_id: 1,
        package_name: "bundler",
        package_version: "1.0",
        purl_type: 'gem'
      }
    ]
  end

  before do
    allow(Sbom::CreateOccurrencesVulnerabilitiesService).to receive(:execute)
  end

  it 'consumes the right event' do
    consume_event(subscriber: described_class, event: event)

    expect(Sbom::CreateOccurrencesVulnerabilitiesService).to have_received(:execute).with(findings)
  end
end
