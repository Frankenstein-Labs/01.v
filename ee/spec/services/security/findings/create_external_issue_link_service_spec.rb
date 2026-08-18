# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Findings::CreateExternalIssueLinkService, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ee_ci_pipeline, project: project) }
  let(:scan) { create(:security_scan, pipeline: pipeline, project: project) }
  let(:security_finding) { create(:security_finding, scan: scan) }
  let(:vulnerability) { create(:vulnerability, project: project) }
  let(:external_tracker) { 'jira' }
  let(:link_type) { 'created' }

  let(:params) do
    {
      security_finding_uuid: security_finding.uuid,
      external_tracker: external_tracker,
      link_type: link_type
    }
  end

  let(:service) { described_class.new(project: project, current_user: user, params: params) }

  subject(:execute_service) { service.execute }

  before_all do
    project.add_developer(user)
  end

  describe '#execute' do
    let(:vulnerability_service_response) { ServiceResponse.success(payload: { vulnerability: vulnerability }) }
    let(:external_link_service_response) { ServiceResponse.success(payload: { record: external_issue_link }) }
    let(:external_issue_link) do
      create(:vulnerabilities_external_issue_link,
        vulnerability: vulnerability,
        external_type: external_tracker,
        link_type: link_type)
    end

    before do
      allow_next_instance_of(Vulnerabilities::FindOrCreateFromSecurityFindingService) do |service|
        allow(service).to receive(:execute).and_return(vulnerability_service_response)
      end

      allow_next_instance_of(VulnerabilityExternalIssueLinks::CreateService) do |service|
        allow(service).to receive(:execute).and_return(external_link_service_response)
      end
    end

    context 'when both services succeed' do
      it 'returns a success response' do
        expect(execute_service).to be_success
      end

      it 'returns the external issue link in the payload' do
        result = execute_service
        expect(result.payload[:record]).to eq(external_issue_link)
      end

      it 'calls FindOrCreateFromSecurityFindingService with correct params' do
        expect(Vulnerabilities::FindOrCreateFromSecurityFindingService).to receive(:new).with(
          project: project,
          current_user: user,
          params: params,
          present_on_default_branch: false,
          state: 'detected'
        )

        execute_service
      end

      it 'calls VulnerabilityExternalIssueLinks::CreateService with correct params' do
        expect(VulnerabilityExternalIssueLinks::CreateService).to receive(:new).with(
          user,
          vulnerability,
          external_tracker,
          link_type: link_type
        )

        execute_service
      end
    end

    context 'when vulnerability creation fails' do
      let(:error_message) { 'Unable to create vulnerability' }
      let(:vulnerability_service_response) { ServiceResponse.error(message: error_message) }

      it 'returns an error response' do
        expect(execute_service).not_to be_success
      end

      it 'returns the error message' do
        result = execute_service
        expect(result.message).to eq(error_message)
      end

      it 'does not call VulnerabilityExternalIssueLinks::CreateService' do
        expect(VulnerabilityExternalIssueLinks::CreateService).not_to receive(:new)

        execute_service
      end
    end

    context 'when external issue link creation fails' do
      let(:error_message) { ['External provider service is not configured to create issues.'] }
      let(:external_link_service_response) { ServiceResponse.error(message: error_message) }

      it 'returns an error response' do
        expect(execute_service).not_to be_success
      end

      it 'returns the error message' do
        result = execute_service
        expect(result.message).to eq(error_message)
      end
    end

    context 'when user does not have permission' do
      before_all do
        project.add_guest(user)
      end

      context 'when vulnerability service checks permissions' do
        let(:vulnerability_service_response) do
          ServiceResponse.error(message: 'Insufficient permissions')
        end

        it 'returns an error' do
          expect(execute_service).not_to be_success
          expect(execute_service.message).to eq('Insufficient permissions')
        end
      end
    end

    context 'with missing params' do
      context 'when security_finding_uuid is missing' do
        let(:params) do
          {
            external_tracker: external_tracker,
            link_type: link_type
          }
        end

        it 'passes nil to vulnerability service' do
          expect(Vulnerabilities::FindOrCreateFromSecurityFindingService).to receive(:new).with(
            project: project,
            current_user: user,
            params: params,
            present_on_default_branch: false,
            state: 'detected'
          )

          execute_service
        end
      end

      context 'when external_tracker is missing' do
        let(:params) do
          {
            security_finding_uuid: security_finding.uuid,
            link_type: link_type
          }
        end

        it 'passes nil to external issue link service' do
          expect(VulnerabilityExternalIssueLinks::CreateService).to receive(:new).with(
            user,
            vulnerability,
            nil,
            link_type: link_type
          )

          execute_service
        end
      end

      context 'when link_type is missing' do
        let(:params) do
          {
            security_finding_uuid: security_finding.uuid,
            external_tracker: external_tracker
          }
        end

        it 'passes nil as link_type to external issue link service' do
          expect(VulnerabilityExternalIssueLinks::CreateService).to receive(:new).with(
            user,
            vulnerability,
            external_tracker,
            link_type: nil
          )

          execute_service
        end
      end
    end
  end
end
