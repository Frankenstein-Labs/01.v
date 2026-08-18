# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Findings::CreateJiraIssueFormUrlService, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ee_ci_pipeline, project: project) }
  let(:scan) { create(:security_scan, pipeline: pipeline, project: project) }
  let(:security_finding) { create(:security_finding, scan: scan) }
  let(:vulnerability) { create(:vulnerability, project: project) }

  let(:params) do
    {
      security_finding_uuid: security_finding.uuid
    }
  end

  let(:service) { described_class.new(project: project, current_user: user, params: params) }

  subject(:execute_service) { service.execute }

  before_all do
    project.add_developer(user)
  end

  describe '#execute' do
    let(:vulnerability_service_response) { ServiceResponse.success(payload: { vulnerability: vulnerability }) }
    let(:jira_url) { 'https://jira.example.com/secure/CreateIssueDetails!init.jspa?pid=10000&issuetype=10001' }

    before do
      allow_next_instance_of(Vulnerabilities::FindOrCreateFromSecurityFindingService) do |service|
        allow(service).to receive(:execute).and_return(vulnerability_service_response)
      end

      allow(service).to receive(:create_jira_issue_url_for).with(vulnerability).and_return(jira_url)
    end

    context 'when vulnerability service succeeds' do
      context 'when Jira integration is configured' do
        it 'returns a success response' do
          expect(execute_service).to be_success
        end

        it 'returns the Jira issue form URL in the payload' do
          result = execute_service
          expect(result.payload[:record]).to eq(jira_url)
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

        it 'calls create_jira_issue_url_for with the vulnerability' do
          expect(service).to receive(:create_jira_issue_url_for).with(vulnerability).and_return(jira_url)

          execute_service
        end
      end

      context 'when Jira integration is not configured' do
        before do
          allow(service).to receive(:create_jira_issue_url_for).with(vulnerability).and_return(nil)
        end

        it 'returns an error response' do
          expect(execute_service).not_to be_success
        end

        it 'returns the appropriate error message' do
          result = execute_service
          expect(result.message).to eq('Jira integration is not configured.')
        end
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

      it 'does not call create_jira_issue_url_for' do
        expect(service).not_to receive(:create_jira_issue_url_for)

        execute_service
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
        let(:params) { {} }

        it 'passes empty params to vulnerability service' do
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
    end
  end
end
