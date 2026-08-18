# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).vulnerabilities', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:security_scan) { create(:security_scan, pipeline: pipeline) }
  let_it_be(:security_finding) do
    create(:security_finding,
      scan: security_scan,
      uuid: vulnerability.finding.uuid,
      severity: :high)
  end

  let_it_be(:flag) { create :vulnerabilities_flag, finding: vulnerability.finding }

  let(:query) do
    %(
      query {
        project(fullPath: "#{project.full_path}") {
          vulnerabilities {
            nodes {
              id
              severity
              flags {
                nodes {
                  id
                  status
                  description
                  confidenceScore
                  origin
                  createdAt
                  updatedAt
                }
              }
              latestFlag {
                id
                status
                description
                confidenceScore
                origin
                createdAt
                updatedAt
              }
              latestSecurityReportFinding {
                uuid
                severity
                originalSeverity
              }
            }
          }
        }
      }
    )
  end

  let(:vulnerabilities) { req.dig('project', 'vulnerabilities', 'nodes') }

  subject(:req) do
    post_graphql(query, current_user: user)
    graphql_data
  end

  context 'when the required features are enabled' do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'when the user has the correct permissions' do
      before_all do
        project.add_developer(user)
        # flag.update! origin: 'duo' # force updated_at
      end

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_security_resource, anything).and_return(true)
      end

      it 'returns vulnerabilities with security findings' do
        expect(vulnerabilities).not_to be_blank
        expect(vulnerabilities.first['latestSecurityReportFinding']).not_to be_nil
      end

      it 'returns all the queried fields', :aggregate_failures do
        vulnerability_data = vulnerabilities.first

        expect(vulnerability_data['id']).not_to be_nil
        expect(vulnerability_data['severity']).not_to be_nil

        finding = vulnerability_data['latestSecurityReportFinding']
        expect(finding['uuid']).not_to be_nil
        expect(finding['severity']).not_to be_nil
        expect(finding['originalSeverity']).not_to be_nil

        flag_data = vulnerability_data['flags']['nodes'].first
        expect(flag_data['id']).not_to be_nil
        expect(flag_data['status']).not_to be_nil
        expect(flag_data['confidenceScore']).not_to be_nil
        expect(flag_data['origin']).not_to be_nil
        expect(flag_data['createdAt']).not_to be_nil
        expect(flag_data['updatedAt']).not_to be_nil

        latest_flag = vulnerability_data['latestFlag']
        expect(latest_flag['id']).not_to be_nil
        expect(latest_flag['status']).not_to be_nil
        expect(latest_flag['confidenceScore']).not_to be_nil
        expect(latest_flag['origin']).not_to be_nil
        expect(latest_flag['createdAt']).not_to be_nil
        expect(latest_flag['updatedAt']).not_to be_nil
      end

      describe 'trackedRefIds filter', :elastic do
        let_it_be(:tracked_ref) { create(:security_project_tracked_context, project: project) }
        let_it_be(:vulnerability_read) do
          create(:vulnerability_read, project: project, tracked_context: tracked_ref)
        end

        let_it_be(:other_tracked_ref) { create(:security_project_tracked_context, project: project) }
        let_it_be(:other_vulnerability_read) do
          create(:vulnerability_read, project: project, tracked_context: other_tracked_ref)
        end

        let(:query) do
          %(
            query {
              project(fullPath: "#{project.full_path}") {
                vulnerabilities(trackedRefIds: ["#{tracked_ref.to_global_id}"]) {
                  nodes {
                    id
                  }
                }
              }
            }
          )
        end

        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

          Elastic::ProcessBookkeepingService.track!(
            vulnerability_read,
            other_vulnerability_read
          )

          ensure_elasticsearch_index!

          allow(user)
            .to receive(:can?)
                  .with(:access_advanced_vulnerability_management, project)
                  .and_return(true)
        end

        it 'returns vulnerabilities from the tracked ref' do
          expect(vulnerabilities.pluck('id')).to contain_exactly(vulnerability_read.vulnerability.to_global_id.to_s)
        end

        it_behaves_like 'validates tracked ref filters' do
          let(:actor) { project }
        end
      end

      describe 'trackedRefsScope filter', :elastic do
        let_it_be(:default_branch_ref) { create(:security_project_tracked_context, :default, project: project) }
        let_it_be(:default_read) do
          create(:vulnerability_read, project: project, tracked_context: default_branch_ref)
        end

        let_it_be(:feature_ref) { create(:security_project_tracked_context, project: project) }
        let_it_be(:feature_read) do
          create(:vulnerability_read, project: project, tracked_context: feature_ref)
        end

        let(:scope_value) { 'DEFAULT_BRANCHES' }

        let(:query) do
          %(
            query {
              project(fullPath: "#{project.full_path}") {
                vulnerabilities(trackedRefsScope: #{scope_value}) {
                  nodes {
                    id
                  }
                }
              }
            }
          )
        end

        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

          Elastic::ProcessBookkeepingService.track!(
            default_read,
            feature_read
          )

          ensure_elasticsearch_index!

          allow(user)
            .to receive(:can?)
                  .with(:access_advanced_vulnerability_management, project)
                  .and_return(true)
        end

        it_behaves_like 'validates tracked ref filters' do
          let(:actor) { project }
        end

        where(:scope_value, :expected_reads) do
          'DEFAULT_BRANCHES' | [ref(:default_read)]
          'ALL_REFS'         | [ref(:default_read), ref(:feature_read)]
        end

        using RSpec::Parameterized::TableSyntax

        with_them do
          it 'returns vulnerabilities as expected' do
            req

            expected_gids = expected_reads.map do |read|
              read.vulnerability.to_global_id.to_s
            end

            expect(vulnerabilities.pluck('id')).to match_array(expected_gids)
          end
        end

        context 'with no filter' do
          let(:query) do
            %(
            query {
              project(fullPath: "#{project.full_path}") {
                vulnerabilities {
                  nodes {
                    id
                  }
                }
              }
            }
          )
          end

          it 'returns vulnerabilities as expected' do
            req

            default_gid = default_read.vulnerability.to_global_id.to_s
            expect(vulnerabilities.pluck('id')).to contain_exactly(default_gid)
          end
        end
      end
    end

    context 'when user is not a member of the project' do
      let(:non_member_user) { create(:user) }

      subject(:req) do
        post_graphql(query, current_user: non_member_user)
        graphql_data
      end

      it 'returns no vulnerabilities' do
        expect(vulnerabilities).to be_blank
      end
    end
  end

  context 'when the required features are disabled' do
    before do
      stub_licensed_features(security_dashboard: false)
    end

    it 'returns no vulnerabilities' do
      expect(vulnerabilities).to be_blank
    end
  end
end
