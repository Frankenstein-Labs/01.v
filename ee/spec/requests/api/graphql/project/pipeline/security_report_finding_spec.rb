# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).pipeline(iid).securityReportFinding',
  feature_category: :continuous_integration do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository, :public) }
  let_it_be(:pipeline) { create(:ci_pipeline, :success, project: project) }
  let_it_be(:build) { create(:ci_build, :success, name: 'sast', pipeline: pipeline) }
  let_it_be(:artifact) { create(:ee_ci_job_artifact, :sast, job: build) }
  let_it_be(:report) { create(:ci_reports_security_report, type: :sast) }
  let_it_be(:user) { create(:user) }
  let_it_be(:scan) { create(:security_scan, :latest_successful, scan_type: :sast, build: build) }
  let(:query) do
    %(
      query {
        project(fullPath: "#{project.full_path}") {
          pipeline(iid: "#{pipeline.iid}") {
            securityReportFinding(uuid: "#{security_finding.uuid}") {
              severity
              reportType
              name: title
              scanner {
                name
              }
              identifiers {
                name
              }
              uuid
              solution
              description
              project {
                fullPath
                visibility
              }
            }
          }
        }
      }
    )
  end

  let(:security_finding) { Security::Finding.first }
  let(:security_report_finding) { subject.dig('project', 'pipeline', 'securityReportFinding') }

  before_all do
    Gitlab::ExclusiveLease.skipping_transaction_check do
      Security::StoreGroupedScansService.new(
        [artifact],
        pipeline,
        'sast'
      ).execute
    end
  end

  subject do
    post_graphql(query, current_user: user)
    graphql_data
  end

  context 'when the required features are enabled' do
    before do
      stub_licensed_features(sast: true, security_dashboard: true)
    end

    context 'when user is member of the project' do
      let(:expected_finding) do
        security_finding.scan.report_findings.find { |f| f.uuid == security_finding.uuid }
      end

      before_all do
        project.add_developer(user)
      end

      it 'returns all the queried fields', :aggregate_failures do
        expect(security_report_finding.dig('project', 'fullPath')).to eq(project.full_path)
        expect(security_report_finding.dig('project', 'visibility')).to eq(project.visibility)
        expect(security_report_finding['identifiers'].length).to eq(expected_finding.identifiers.length)
        expect(security_report_finding['severity']).to eq(expected_finding.severity.upcase)
        expect(security_report_finding['reportType']).to eq(expected_finding.report_type.upcase)
        expect(security_report_finding['name']).to eq(expected_finding.name)
        expect(security_report_finding['uuid']).to eq(expected_finding.uuid)
        expect(security_report_finding['solution']).to eq(expected_finding.solution)
        expect(security_report_finding['description']).to eq(expected_finding.description)
      end

      context 'when the finding has been dismissed' do
        let!(:vulnerability) { create(:vulnerability, :dismissed, project: project) }
        let!(:vulnerability_finding) do
          create(
            :vulnerabilities_finding,
            project: project,
            vulnerability: vulnerability,
            uuid: security_finding.uuid
          )
        end

        it 'returns a finding in the dismissed state' do
          expect(security_report_finding['name']).to eq(expected_finding.name)
        end
      end

      context 'when there is a severity override' do
        let!(:vulnerability) { create(:vulnerability, severity: :critical, project: project) }
        let!(:vulnerability_finding) do
          create(
            :vulnerabilities_finding,
            project: project,
            vulnerability: vulnerability,
            uuid: security_finding.uuid
          )
        end

        let!(:severity_override) do
          create(
            :vulnerability_severity_override,
            vulnerability: vulnerability,
            author: user,
            original_severity: expected_finding.severity,
            new_severity: :critical
          )
        end

        it 'returns the vulnerability severity' do
          expect(security_report_finding['severity']).to eq('CRITICAL')
        end
      end

      it 'does not have N+1 queries' do
        control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: user) }

        new_vulnerability = create(:vulnerability, :dismissed, project: project)
        create(
          :vulnerabilities_finding,
          project: project,
          vulnerability: new_vulnerability,
          uuid: Security::Finding.second.uuid
        )
        create(
          :vulnerability_severity_override,
          vulnerability: new_vulnerability,
          author: user
        )

        expect { post_graphql(query, current_user: user) }.not_to exceed_query_limit(control)
      end
    end

    context 'when user is not a member of the project' do
      it 'returns no vulnerability findings' do
        expect(security_report_finding).to be_nil
      end
    end
  end

  context 'when the required features are disabled' do
    before do
      stub_licensed_features(sast: false, security_dashboard: false)
    end

    it 'returns no vulnerability findings' do
      expect(security_report_finding).to be_nil
    end
  end
end
