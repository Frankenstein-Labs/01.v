# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Creating an External Issue Link from a Security::Finding', feature_category: :vulnerability_management do
  include GraphqlHelpers

  before do
    stub_licensed_features(security_dashboard: true, jira_vulnerabilities_integration: true)
  end

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:pipeline) { create(:ci_pipeline, :success, project: project) }

  let_it_be(:build_sast) { create(:ci_build, :success, name: 'sast', pipeline: pipeline) }
  let_it_be(:artifact_sast) do
    create(:ee_ci_job_artifact, :sast, job: build_sast)
  end

  let_it_be(:scan) { create(:security_scan, :latest_successful, scan_type: :sast, build: artifact_sast.job) }

  let_it_be(:security_findings) { create_security_findings }

  let(:security_finding) { security_findings.first }
  let(:security_finding_uuid) { security_finding.uuid }
  let(:project_gid) { GitlabSchema.id_from_object(project) }

  let(:mutation_name) { :security_finding_external_issue_link_create }
  let(:mutation) do
    graphql_mutation(
      mutation_name,
      project: project_gid,
      uuid: security_finding_uuid,
      link_type: 'CREATED',
      external_tracker: 'JIRA'
    )
  end

  def mutation_response
    graphql_mutation_response(mutation_name)
  end

  context 'when the user does not have permission' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create a new vulnerability' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }.not_to change { Vulnerability.count }
    end

    it 'does not create a new external issue link' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.not_to change { Vulnerabilities::ExternalIssueLink.count }
    end
  end

  context 'when the user has permission' do
    before_all do
      project.add_maintainer(current_user)
    end

    context 'when security_dashboard is disabled' do
      before do
        stub_licensed_features(security_dashboard: false)
      end

      it_behaves_like 'a mutation that returns top-level errors',
        errors: ['The resource that you are attempting to access does not ' \
          'exist or you don\'t have permission to perform this action']
    end

    context 'when security_dashboard is enabled' do
      context 'when jira is not configured' do
        it 'responds with error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_response['errors'])
            .to include('External provider service is not configured to create issues.')
        end

        it 'does not create an external issue link' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.not_to change { Vulnerabilities::ExternalIssueLink.count }
        end
      end

      context 'when jira is configured' do
        let!(:jira_integration) do
          create(:jira_integration,
            project: project,
            vulnerabilities_enabled: true,
            project_key: 'GV',
            vulnerabilities_issuetype: '10000')
        end

        context 'when issue creation succeeds' do
          before do
            stub_request(:get, 'https://jira.example.com/rest/api/2/project/GV')
              .to_return(status: 200, body: { 'id' => '10000' }.to_json)
            stub_request(:post, 'https://jira.example.com/rest/api/2/issue')
              .to_return(
                status: 200,
                body: jira_created_issue.to_json
              )
          end

          let(:jira_created_issue) do
            {
              'id' => external_issue_id,
              'key' => 'GV-123',
              fields: {
                project: { id: '10000' },
                issuetype: { id: '10000' },
                summary: "A summary",
                description: "Security finding from GitLab",
                created: '2025-01-15T10:00:00.000+0000',
                updated: '2025-01-15T10:00:00.000+0000',
                resolutiondate: '2020-06-27T13:23:51.000+0000',
                labels: ['backend'],
                status: { name: 'To Do' },
                key: 'GV-6',
                assignee: nil,
                reporter: { name: 'admin', displayName: 'Admin' }
              }
            }
          end

          context 'and saving external issue link succeeds' do
            let(:external_issue_id) { '10000' }

            it 'does create a new vulnerability' do
              expect { post_graphql_mutation(mutation, current_user: current_user) }
                .to change { Vulnerability.count }.by(1)
            end

            it 'creates the external issue link and returns nil for external issue to be fetched using query',
              :aggregate_failures do
              expect { post_graphql_mutation(mutation, current_user: current_user) }
                .to change { Vulnerabilities::ExternalIssueLink.count }.by(1)
              expect(mutation_response['errors']).to be_empty
              expect(mutation_response.dig('externalIssueLink', 'externalIssue')).to be_nil
            end

            it_behaves_like 'authorizing granular token permissions for GraphQL',
              :create_vulnerability_external_issue_link do
              let(:user) { current_user }
              let(:boundary_object) { project }
              let(:authz_mutation) do
                graphql_mutation(
                  mutation_name,
                  {
                    project: project_gid,
                    uuid: security_finding_uuid,
                    link_type: 'CREATED',
                    external_tracker: 'JIRA'
                  },
                  'errors'
                )
              end

              let(:request) { post_graphql_mutation(authz_mutation, token: { personal_access_token: pat }) }
            end
          end

          context 'and saving external issue link fails' do
            let(:external_issue_id) { nil }

            it 'does not create the external issue link' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
              end.not_to change { Vulnerabilities::ExternalIssueLink.count }
            end

            it 'returns errors' do
              post_graphql_mutation(mutation, current_user: current_user)

              expect(mutation_response['errors']).not_to be_empty
              expect(mutation_response['externalIssueLink']).to be_nil
            end
          end
        end

        context 'when issue creation fails' do
          before do
            stub_request(:get, 'https://jira.example.com/rest/api/2/project/GV')
              .to_return(status: 200, body: { 'id' => '10000' }.to_json)
            stub_request(:post, 'https://jira.example.com/rest/api/2/issue')
              .to_return(status: 400, body: { 'errors' => ['bad request'] }.to_json)
          end

          it 'does not create the external issue link' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.not_to change { Vulnerabilities::ExternalIssueLink.count }
          end
        end
      end
    end
  end

  def create_security_findings
    report = create(:ci_reports_security_report, pipeline: pipeline, type: :sast)
    sast_content = File.read(artifact_sast.file.path)
    Gitlab::Ci::Parsers::Security::Sast.parse!(sast_content, report)
    report.merge!(report)
    report.findings.map do |finding|
      create(
        :security_finding,
        severity: finding.severity,
        uuid: finding.uuid,
        scan: scan
      )
    end
  end
end
