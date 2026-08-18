# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).pipeline(iid).securityReportFindings',
  feature_category: :continuous_integration do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository, :public) }
  let_it_be(:pipeline) { create(:ci_pipeline, :success, project: project) }
  let_it_be(:user) { create(:user) }
  let(:query) do
    %(
      query {
        project(fullPath: "#{project.full_path}") {
          pipeline(iid: "#{pipeline.iid}") {
            securityReportFindings(reportType: ["sast", "dast"]) {
              nodes {
                severity
                originalSeverity
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
      }
    )
  end

  let(:security_report_findings) { subject.dig('project', 'pipeline', 'securityReportFindings', 'nodes') }

  before_all do
    dast_job = create(:ci_build, :success, name: 'dast_job', pipeline: pipeline, project: project)
    dast_artifact = create(:ee_ci_job_artifact, :dast_large_scanned_resources_field, job: dast_job, project: project)

    sast_job = create(:ci_build, :success, name: 'sast_job', pipeline: pipeline, project: project)
    sast_artifact = create(:ee_ci_job_artifact, :sast, job: sast_job, project: project)

    # StoreGroupedScansService acquires a Gitlab::Instrumentation::ExclusiveLock
    # We have checks in place to raise errors if these locks are acquired
    # within transactions.  Because our tests all run inside a database
    # cleaner transaction these checks need to be skipped here.
    Gitlab::ExclusiveLease.skipping_transaction_check do
      # This causes the job artifacts to be ingested and security_findings
      # records to be created with the correct associations to scanners
      # and the pipeline.
      Security::StoreGroupedScansService.new([dast_artifact, sast_artifact], pipeline, 'sast').execute
    end
  end

  subject do
    post_graphql(query, current_user: user)
    graphql_data
  end

  context 'when the required features are enabled' do
    before do
      stub_licensed_features(sast: true, dast: true, security_dashboard: true)
    end

    context 'when user is member of the project' do
      before_all do
        project.add_developer(user)
      end

      it 'returns all the vulnerability findings' do
        expect(security_report_findings.length).to eq(25)
      end

      it 'returns all the queried fields', :aggregate_failures do
        security_report_finding = security_report_findings.first

        expect(security_report_finding.dig('project', 'fullPath')).to eq(project.full_path)
        expect(security_report_finding.dig('project', 'visibility')).to eq(project.visibility)
        expect(security_report_finding['identifiers'].length).to eq(3)
        expect(security_report_finding['severity']).not_to be_nil
        expect(security_report_finding['originalSeverity']).not_to be_nil
        expect(security_report_finding['reportType']).not_to be_nil
        expect(security_report_finding['name']).not_to be_nil
        expect(security_report_finding['uuid']).not_to be_nil
        expect(security_report_finding['solution']).not_to be_nil
        expect(security_report_finding['description']).not_to be_nil
      end

      describe 'pagination' do
        let(:query) { pagination_query(pagination_arguments) }

        let(:actual_uuids) { security_report_findings.map { |finding| finding.fetch('uuid') } }

        context 'with only :first argument' do
          let(:pagination_arguments) { "first: 5" }

          it 'returns the first 5 findings' do
            expected_uuids = Security::Finding.all.order(severity: :desc, id: :asc).limit(5).map(&:uuid)
            expect(actual_uuids).to eq(expected_uuids)
          end
        end

        context 'with :first and an empty :after argument' do
          let(:pagination_arguments) { "first: 5,after: \"\"" }

          it 'treats the empty cursor as absent and returns the first 5 findings' do
            expected_uuids = Security::Finding.all.order(severity: :desc, id: :asc).limit(5).map(&:uuid)
            expect(actual_uuids).to eq(expected_uuids)
          end
        end

        context 'with :first and :after arguments' do
          let(:pagination_arguments) { "first: 5,after: \"#{encode(5)}\"" }

          it 'returns the 6th to 10th findings' do
            expected_uuids = Security::Finding.all.order(severity: :desc, id: :asc).offset(5).limit(5).map(&:uuid)
            expect(actual_uuids).to eq(expected_uuids)
          end
        end

        context 'with :last and :before arguments' do
          let(:pagination_arguments) { "last: 10,before: \"#{encode(21)}\"" }

          it 'returns the 10th to 20th findings' do
            expected_uuids = Security::Finding.all.order(severity: :desc, id: :asc).offset(10).limit(10).map(&:uuid)
            expect(actual_uuids).to eq(expected_uuids)
          end
        end

        context 'when fetching the third page using endCursors' do
          it 'returns all findings exactly once across all pages' do
            all_uuids = []
            cursor = nil

            3.times do
              args = "first: 1"
              args += ",after: \"#{cursor}\"" if cursor

              post_graphql(pagination_query(args, include_page_info: true), current_user: user)
              page = graphql_data.dig('project', 'pipeline', 'securityReportFindings')
              all_uuids.concat(page['nodes'].map { |f| f['uuid'] })
              cursor = page.dig('pageInfo', 'endCursor')
            end

            expected_uuids = Security::Finding.all.order(severity: :desc, id: :asc).limit(3).pluck(:uuid)
            expect(all_uuids).to eq(expected_uuids)
          end
        end

        def pagination_query(pagination_arguments, include_page_info: false)
          page_info_fragment = include_page_info ? "pageInfo { endCursor }" : ""

          %(
            query {
              project(fullPath: "#{project.full_path}") {
                pipeline(iid: "#{pipeline.iid}") {
                  securityReportFindings(#{pagination_arguments}, reportType: ["sast", "dast"]) {
                    nodes {
                      title
                      reportType
                      uuid
                    }
                    #{page_info_fragment}
                  }
                }
              }
            }
          )
        end

        # Keyset pagination cursors encode the sort key values (severity, id)
        def encode(offset)
          finding = Security::Finding.all.order(severity: :desc, id: :asc).offset(offset - 1).first
          return unless finding

          Gitlab::Pagination::Keyset::Paginator::Base64CursorConverter.dump(
            severity: finding.severity,
            id: finding.id.to_s
          )
        end
      end
    end

    context 'when user is not a member of the project' do
      it 'returns no vulnerability findings' do
        expect(security_report_findings).to be_blank
      end
    end
  end

  context 'when the required features are disabled' do
    before do
      stub_licensed_features(sast: false, dast: false, security_dashboard: false)
    end

    it 'returns no vulnerability findings' do
      expect(security_report_findings).to be_blank
    end
  end
end
