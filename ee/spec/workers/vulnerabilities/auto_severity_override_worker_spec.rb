# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::AutoSeverityOverrideWorker, '#handle_event',
  feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:vulnerability) { create(:vulnerability, :detected, project: project) }

  let(:vulnerability_ids) { [vulnerability.id] }
  let(:pipeline_id) { pipeline.id }
  let(:findings) do
    [
      {
        'uuid' => SecureRandom.uuid,
        'project_id' => project.id,
        'pipeline_id' => pipeline_id,
        'vulnerability_id' => vulnerability.id,
        'package_name' => 'test-package',
        'package_version' => '1.0.0',
        'purl_type' => 'npm'
      }.compact_blank
    ]
  end

  let(:event_data) do
    {
      'findings' => findings
    }
  end

  let(:event) { Sbom::VulnerabilitiesCreatedEvent.new(data: event_data) }

  subject(:worker) { described_class.new }

  shared_examples 'does not call AutoSeverityOverrideService' do
    it 'does not call AutoSeverityOverrideService' do
      expect(Vulnerabilities::AutoSeverityOverrideService).not_to receive(:new)

      worker.handle_event(event)
    end
  end

  context 'when pipeline_id and vulnerability_ids are present' do
    let(:auto_severity_override_service) { instance_double(Vulnerabilities::AutoSeverityOverrideService) }
    let(:override_count) { 1 }
    let(:service_response) { ServiceResponse.success(payload: { count: override_count }) }

    before do
      stub_licensed_features(security_orchestration_policies: true)
      allow(Vulnerabilities::AutoSeverityOverrideService).to receive(:new)
        .with(pipeline, vulnerability_ids)
        .and_return(auto_severity_override_service)
      allow(auto_severity_override_service).to receive(:execute).and_return(service_response)
    end

    it 'calls AutoSeverityOverrideService with correct parameters' do
      worker.handle_event(event)

      expect(Vulnerabilities::AutoSeverityOverrideService).to have_received(:new)
        .with(pipeline, vulnerability_ids)
      expect(auto_severity_override_service).to have_received(:execute)
    end

    it 'logs success when service overrides vulnerabilities' do
      expect(Gitlab::AppJsonLogger).to receive(:debug).with(
        message: "Auto-overrode vulnerability severities from event",
        project_id: project.id,
        pipeline_id: pipeline.id,
        count: 1
      )

      worker.handle_event(event)
    end

    context 'when no vulnerabilities were overridden' do
      let(:override_count) { 0 }

      it 'does not log' do
        expect(Gitlab::AppJsonLogger).not_to receive(:debug)

        worker.handle_event(event)
      end
    end

    context 'when service fails' do
      let(:service_response) do
        ServiceResponse.error(
          message: 'Could not override vulnerability severities',
          reason: 'ActiveRecord error'
        )
      end

      it 'logs error when service fails' do
        expect(Gitlab::AppJsonLogger).to receive(:error).with(
          message: "Failed to auto-override vulnerability severities from event",
          project_id: project.id,
          pipeline_id: pipeline.id,
          error: 'Could not override vulnerability severities',
          reason: 'ActiveRecord error'
        )

        worker.handle_event(event)
      end
    end
  end

  context 'when licensed feature is not available' do
    before do
      stub_licensed_features(security_orchestration_policies: false)
    end

    it_behaves_like 'does not call AutoSeverityOverrideService'
  end

  context 'when pipeline_id is missing' do
    let(:pipeline_id) { nil }

    it_behaves_like 'does not call AutoSeverityOverrideService'
  end

  context 'when findings are missing' do
    let(:event_data) do
      {
        'findings' => []
      }
    end

    it_behaves_like 'does not call AutoSeverityOverrideService'
  end

  context 'when pipeline does not exist' do
    let(:pipeline_id) { non_existing_record_id }

    it_behaves_like 'does not call AutoSeverityOverrideService'
  end
end
