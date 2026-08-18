# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::AutoDismissWorker, '#handle_event', feature_category: :security_policy_management do
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

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  shared_examples 'does not call AutoDismissService' do
    it 'does not call AutoDismissService' do
      expect(Vulnerabilities::AutoDismissService).not_to receive(:new)

      worker.handle_event(event)
    end
  end

  context 'when pipeline_id and vulnerability_ids are present' do
    let(:auto_dismiss_service) { instance_double(Vulnerabilities::AutoDismissService) }
    let(:dismissed_count) { 1 }
    let(:service_response) { ServiceResponse.success(payload: { count: dismissed_count }) }

    before do
      allow(Vulnerabilities::AutoDismissService).to receive(:new)
        .with(pipeline, vulnerability_ids)
        .and_return(auto_dismiss_service)
      allow(auto_dismiss_service).to receive(:execute).and_return(service_response)
    end

    it 'calls AutoDismissService with correct parameters' do
      worker.handle_event(event)

      expect(Vulnerabilities::AutoDismissService).to have_received(:new)
        .with(pipeline, vulnerability_ids)
      expect(auto_dismiss_service).to have_received(:execute)
    end

    it 'logs success when service succeeds' do
      expect(Gitlab::AppJsonLogger).to receive(:debug).with(
        message: "Auto-dismissed vulnerabilities from event",
        project_id: project.id,
        pipeline_id: pipeline.id,
        count: 1
      )

      worker.handle_event(event)
    end

    context 'when no vulnerabilities were dismissed' do
      let(:dismissed_count) { 0 }

      it 'does not log' do
        expect(Gitlab::AppJsonLogger).not_to receive(:debug)

        worker.handle_event(event)
      end
    end

    context 'when service fails' do
      let(:service_response) do
        ServiceResponse.error(
          message: 'Could not dismiss vulnerabilities',
          reason: 'Bot user does not have permission'
        )
      end

      it 'logs error when service fails' do
        expect(Gitlab::AppJsonLogger).to receive(:error).with(
          message: "Failed to auto-dismiss vulnerabilities from event",
          project_id: project.id,
          pipeline_id: pipeline.id,
          error: 'Could not dismiss vulnerabilities',
          reason: 'Bot user does not have permission'
        )

        worker.handle_event(event)
      end
    end
  end

  context 'when pipeline_id is missing' do
    let(:pipeline_id) { nil }

    it_behaves_like 'does not call AutoDismissService'
  end

  context 'when findings are missing' do
    let(:event_data) do
      {
        'findings' => []
      }
    end

    it_behaves_like 'does not call AutoDismissService'
  end

  context 'when pipeline does not exist' do
    let(:pipeline_id) { non_existing_record_id }

    it_behaves_like 'does not call AutoDismissService'
  end

  context 'when project does not have security_orchestration_policies feature' do
    before do
      stub_licensed_features(security_orchestration_policies: false)
    end

    it_behaves_like 'does not call AutoDismissService'
  end
end
