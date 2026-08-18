# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Security metrics through GroupQuery', :elastic_helpers, :freeze_time, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project_1) { create(:project, :public, group: group) }
  let_it_be(:project_2) { create(:project, :public, group: subgroup) }
  let_it_be(:project_3) { create(:project, :public, group: group) }

  let(:security_metrics_data) { graphql_data['group']['securityMetrics'] }
  let(:vulnerabilities_per_severity_data) { security_metrics_data&.dig('vulnerabilitiesPerSeverity') }
  let(:vulnerabilities_over_time_data) { security_metrics_data&.dig('vulnerabilitiesOverTime', 'nodes') }
  let(:risk_score_data) { security_metrics_data&.dig('riskScore') }

  let(:start_date) { 1.week.ago(Time.zone.now).to_date }
  let(:end_date) { Time.zone.now.to_date }

  let(:base_query_fields) do
    <<~GRAPHQL
      vulnerabilitiesPerSeverity {
        critical { count }
        high { count }
        medium { count }
        low { count }
        info { count }
        unknown { count }
      }
      vulnerabilitiesOverTime(startDate: "#{start_date.iso8601}", endDate: "#{end_date.iso8601}") {
        nodes {
          date
          count
          bySeverity {
            severity
            count
          }
          byReportType {
            reportType
            count
          }
        }
      }
      riskScore {
        score
        rating
        byProject {
          nodes {
            rating
            score
            project {
              id
              name
            }
          }
        }
      }
    GRAPHQL
  end

  def query(group_path: group.full_path)
    graphql_query_for(
      'group',
      { 'fullPath' => group_path },
      "securityMetrics { #{base_query_fields} }"
    )
  end

  before do
    stub_licensed_features(security_dashboard: true)
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'when user has access' do
    before_all do
      group.add_maintainer(current_user)
    end

    context 'with vulnerabilities data' do
      let_it_be(:vulnerability_1) do
        create(:vulnerability, :critical, :with_finding, project: project_1, created_at: 2.days.ago(Time.zone.now))
      end

      let_it_be(:vulnerability_2) do
        create(:vulnerability, :high, :with_finding, project: project_2, created_at: 1.day.ago(Time.zone.now))
      end

      let_it_be(:vulnerability_3) do
        create(:vulnerability, :medium, :with_finding, project: project_3, created_at: 1.day.ago(Time.zone.now))
      end

      before do
        allow_next_instance_of(
          ::Search::AdvancedFinders::Security::Vulnerability::CountBySeverityFinder) do |finder|
          allow(finder).to receive(:execute).and_return(
            {
              'critical' => { 'count' => 1, 'avg_detected_at' => {}, 'median_detected_at' => {} },
              'high' => { 'count' => 1, 'avg_detected_at' => {}, 'median_detected_at' => {} },
              'medium' => { 'count' => 1, 'avg_detected_at' => {}, 'median_detected_at' => {} },
              'low' => { 'count' => 0, 'avg_detected_at' => {}, 'median_detected_at' => {} },
              'info' => { 'count' => 0, 'avg_detected_at' => {}, 'median_detected_at' => {} },
              'unknown' => { 'count' => 0, 'avg_detected_at' => {}, 'median_detected_at' => {} }
            }
          )
        end

        allow_next_instance_of(
          ::Search::AdvancedFinders::Security::Vulnerability::CountOverTimeFinder
        ) do |finder|
          allow(finder).to receive(:execute).and_return([
            {
              date: 2.days.ago(Time.zone.now).to_date.iso8601,
              count: 1,
              by_severity: [{ severity: 'critical', count: 1 }],
              by_report_type: [{ report_type: 'sast', count: 1 }]
            },
            {
              date: 1.day.ago(Time.zone.now).to_date.iso8601,
              count: 2,
              by_severity: [
                { severity: 'high', count: 1 },
                { severity: 'medium', count: 1 }
              ],
              by_report_type: [{ report_type: 'sast', count: 2 }]
            }
          ])
        end

        allow_next_instance_of(::Resolvers::Security::RiskScoreResolver) do |resolver|
          allow(resolver).to receive(:resolve).and_return(
            {
              score: 7.5,
              rating: 'high',
              factors: {
                vulnerabilities_average_score: {
                  factor: 0.8
                }
              },
              by_project: [
                {
                  rating: 'medium',
                  score: 5.2,
                  project: project_1
                }
              ]
            }
          )
        end
      end

      it_behaves_like 'a working graphql query' do
        before do
          post_graphql(query, current_user: current_user)
        end
      end

      it 'returns security metrics successfully' do
        simple_query = graphql_query_for(
          'group',
          { 'fullPath' => group.full_path },
          <<~GRAPHQL
            securityMetrics {
              vulnerabilitiesPerSeverity {
                critical { count }
                high { count }
                medium { count }
                low { count }
              }
            }
          GRAPHQL
        )

        post_graphql(simple_query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_errors).to be_nil
        expect(security_metrics_data).not_to be_nil

        severity_data = security_metrics_data['vulnerabilitiesPerSeverity']
        expect(severity_data['critical']['count']).to eq(1)
        expect(severity_data['high']['count']).to eq(1)
        expect(severity_data['medium']['count']).to eq(1)
        expect(severity_data['low']['count']).to eq(0)
      end

      describe 'vulnerabilities per severity' do
        it 'returns vulnerability counts by severity' do
          severity_query = graphql_query_for(
            'group',
            { 'fullPath' => group.full_path },
            <<~GRAPHQL
              securityMetrics {
                vulnerabilitiesPerSeverity {
                  critical { count }
                  high { count }
                  medium { count }
                  low { count }
                  info { count }
                  unknown { count }
                }
              }
            GRAPHQL
          )

          post_graphql(severity_query, current_user: current_user)

          expect(vulnerabilities_per_severity_data).to include(
            'critical' => { 'count' => 1 },
            'high' => { 'count' => 1 },
            'medium' => { 'count' => 1 },
            'low' => { 'count' => 0 },
            'info' => { 'count' => 0 },
            'unknown' => { 'count' => 0 }
          )
        end

        context 'with date range arguments' do
          let(:start_date) { 3.days.ago(Time.zone.now).to_date }
          let(:end_date) { Time.zone.now.to_date }

          it 'filters vulnerabilities by date range' do
            date_range_query = graphql_query_for(
              'group',
              { 'fullPath' => group.full_path },
              <<~GRAPHQL
                securityMetrics {
                  vulnerabilitiesPerSeverity(startDate: "#{start_date.iso8601}", endDate: "#{end_date.iso8601}") {
                    critical { count }
                    high { count }
                    medium { count }
                    low { count }
                  }
                }
              GRAPHQL
            )

            post_graphql(date_range_query, current_user: current_user)

            expect(vulnerabilities_per_severity_data).to include(
              'critical' => { 'count' => 1 },
              'high' => { 'count' => 1 },
              'medium' => { 'count' => 1 }
            )
          end
        end

        context 'without date range arguments' do
          it 'returns all vulnerabilities without date filtering' do
            no_date_query = graphql_query_for(
              'group',
              { 'fullPath' => group.full_path },
              <<~GRAPHQL
                securityMetrics {
                  vulnerabilitiesPerSeverity {
                    critical { count }
                    high { count }
                    medium { count }
                    low { count }
                  }
                }
              GRAPHQL
            )

            post_graphql(no_date_query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:ok)
            expect(graphql_errors).to be_nil
            expect(vulnerabilities_per_severity_data).to include(
              'critical' => { 'count' => 1 },
              'high' => { 'count' => 1 },
              'medium' => { 'count' => 1 },
              'low' => { 'count' => 0 }
            )
          end
        end
      end

      describe 'vulnerabilities over time' do
        it 'returns vulnerability metrics over time' do
          post_graphql(query, current_user: current_user)

          expect(vulnerabilities_over_time_data).to be_an(Array)
          expect(vulnerabilities_over_time_data).to have_attributes(size: 2)

          first_day = vulnerabilities_over_time_data.first
          expect(first_day).to include(
            'date' => 2.days.ago(Time.zone.now).to_date.iso8601,
            'count' => 1
          )
          expect(first_day['bySeverity']).to include(
            { 'severity' => 'CRITICAL', 'count' => 1 }
          )
          expect(first_day['byReportType']).to include(
            { 'reportType' => 'SAST', 'count' => 1 }
          )
        end

        context 'when querying only bySeverity' do
          let(:severity_only_query) do
            graphql_query_for(
              'group',
              { 'fullPath' => group.full_path },
              <<~GRAPHQL
                securityMetrics {
                  vulnerabilitiesOverTime(startDate: "#{start_date.iso8601}", endDate: "#{end_date.iso8601}") {
                    nodes {
                      date
                      count
                      bySeverity {
                        severity
                        count
                      }
                    }
                  }
                }
              GRAPHQL
            )
          end

          before do
            allow_next_instance_of(
              ::Search::AdvancedFinders::Security::Vulnerability::CountOverTimeFinder
            ) do |finder|
              allow(finder).to receive(:execute).and_return([
                {
                  date: 2.days.ago(Time.zone.now).to_date.iso8601,
                  count: 1,
                  by_severity: [{ severity: 'critical', count: 1 }]
                },
                {
                  date: 1.day.ago(Time.zone.now).to_date.iso8601,
                  count: 2,
                  by_severity: [
                    { severity: 'high', count: 1 },
                    { severity: 'medium', count: 1 }
                  ]
                }
              ])
            end
          end

          it 'returns only bySeverity data without byReportType' do
            post_graphql(severity_only_query, current_user: current_user)

            expect(vulnerabilities_over_time_data).to be_an(Array)
            expect(vulnerabilities_over_time_data).to have_attributes(size: 2)

            first_day = vulnerabilities_over_time_data.first
            expect(first_day).to include(
              'date' => 2.days.ago(Time.zone.now).to_date.iso8601,
              'count' => 1
            )
            expect(first_day['bySeverity']).to include(
              { 'severity' => 'CRITICAL', 'count' => 1 }
            )
            expect(first_day).not_to have_key('byReportType')
          end
        end

        context 'when querying only byReportType' do
          let(:report_type_only_query) do
            graphql_query_for(
              'group',
              { 'fullPath' => group.full_path },
              <<~GRAPHQL
                securityMetrics {
                  vulnerabilitiesOverTime(startDate: "#{start_date.iso8601}", endDate: "#{end_date.iso8601}") {
                    nodes {
                      date
                      count
                      byReportType {
                        reportType
                        count
                      }
                    }
                  }
                }
              GRAPHQL
            )
          end

          before do
            allow_next_instance_of(
              ::Search::AdvancedFinders::Security::Vulnerability::CountOverTimeFinder
            ) do |finder|
              allow(finder).to receive(:execute).and_return([
                {
                  date: 2.days.ago(Time.zone.now).to_date.iso8601,
                  count: 1,
                  by_report_type: [{ report_type: 'sast', count: 1 }]
                },
                {
                  date: 1.day.ago(Time.zone.now).to_date.iso8601,
                  count: 2,
                  by_report_type: [
                    { report_type: 'sast', count: 1 },
                    { report_type: 'dast', count: 1 }
                  ]
                }
              ])
            end
          end

          it 'returns only byReportType data without bySeverity' do
            post_graphql(report_type_only_query, current_user: current_user)

            expect(vulnerabilities_over_time_data).to be_an(Array)
            expect(vulnerabilities_over_time_data).to have_attributes(size: 2)

            first_day = vulnerabilities_over_time_data.first
            expect(first_day).to include(
              'date' => 2.days.ago(Time.zone.now).to_date.iso8601,
              'count' => 1
            )
            expect(first_day['byReportType']).to include(
              { 'reportType' => 'SAST', 'count' => 1 }
            )
            expect(first_day).not_to have_key('bySeverity')
          end
        end
      end

      describe 'risk score' do
        it 'returns risk score information' do
          post_graphql(query, current_user: current_user)

          expect(risk_score_data).to include('score', 'rating')
          expect(risk_score_data['score']).to be_a(Numeric)
          expect(risk_score_data['rating']).to be_a(String)
        end
      end

      context 'with project filtering' do
        it 'filters by specific project IDs' do
          project_ids = [project_1.to_global_id.to_s, project_2.to_global_id.to_s]
          project_filter_query = graphql_query_for(
            'group',
            { 'fullPath' => group.full_path },
            <<~GRAPHQL
              securityMetrics(projectId: [#{project_ids.map { |id| "\"#{id}\"" }.join(', ')}]) {
                vulnerabilitiesPerSeverity {
                  critical { count }
                  high { count }
                  medium { count }
                  low { count }
                }
              }
            GRAPHQL
          )

          post_graphql(project_filter_query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(graphql_errors).to be_nil
          expect(security_metrics_data).not_to be_nil

          severity_data = security_metrics_data['vulnerabilitiesPerSeverity']
          expect(severity_data['critical']['count']).to eq(1)
          expect(severity_data['high']['count']).to eq(1)
        end
      end

      context 'with report type filtering' do
        it 'filters by specific report types' do
          report_type_query = graphql_query_for(
            'group',
            { 'fullPath' => group.full_path },
            <<~GRAPHQL
              securityMetrics(reportType: [SAST, DAST]) {
                vulnerabilitiesPerSeverity {
                  critical { count }
                  high { count }
                  medium { count }
                  low { count }
                }
              }
            GRAPHQL
          )

          post_graphql(report_type_query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(graphql_errors).to be_nil
          expect(security_metrics_data).not_to be_nil
        end
      end
    end

    context 'without vulnerabilities data' do
      let_it_be(:empty_group) { create(:group) }

      before_all do
        empty_group.add_maintainer(current_user)
      end

      it 'returns empty security metrics' do
        allow_next_instance_of(::Resolvers::Security::VulnerabilitiesPerSeverityResolver) do |resolver|
          allow(resolver).to receive(:resolve).and_return(
            {
              'critical' => { count: 0 },
              'high' => { count: 0 },
              'medium' => { count: 0 },
              'low' => { count: 0 },
              'info' => { count: 0 },
              'unknown' => { count: 0 }
            }
          )
        end

        allow_next_instance_of(::Resolvers::Security::VulnerabilitiesOverTimeResolver) do |resolver|
          allow(resolver).to receive(:resolve).and_return([])
        end

        allow_next_instance_of(::Resolvers::Security::RiskScoreResolver) do |resolver|
          allow(resolver).to receive(:resolve).and_return(nil)
        end

        simple_query = graphql_query_for(
          'group',
          { 'fullPath' => empty_group.full_path },
          "securityMetrics { #{base_query_fields} }"
        )

        post_graphql(simple_query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_errors).to be_nil
        expect(security_metrics_data).not_to be_nil

        severity_data = security_metrics_data['vulnerabilitiesPerSeverity']
        expect(severity_data['critical']['count']).to eq(0)
        expect(severity_data['high']['count']).to eq(0)
        expect(severity_data['medium']['count']).to eq(0)
        expect(severity_data['low']['count']).to eq(0)
      end
    end
  end

  describe 'when user does not have access' do
    it 'returns null for security metrics' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil
      expect(security_metrics_data).to be_nil
    end
  end

  # #security
  describe 'riskScore.byProject authorization' do
    let_it_be(:private_project) { create(:project, :private, group: group) }
    let_it_be(:attacker) { create(:user) }
    let_it_be(:member_role) do
      create(:member_role, :minimal_access, namespace: group, read_vulnerability: true)
    end

    before_all do
      create(:group_member, :minimal_access, member_role: member_role, source: group, user: attacker)
    end

    before do
      stub_licensed_features(security_dashboard: true, custom_roles: true)

      allow_next_instance_of(::Search::AdvancedFinders::Security::Vulnerability::RiskScoresFinder) do |finder|
        allow(finder).to receive(:execute).and_return({
          total_risk_score: 0.5,
          total_project_count: 1,
          risk_score_by_project: {
            private_project.id => 0.5
          }
        })
      end
    end

    it 'does not expose private project data to a user without read_project permission' do
      risk_score_query = graphql_query_for(
        'group',
        { 'fullPath' => group.full_path },
        <<~GRAPHQL
          securityMetrics {
            riskScore {
              byProject {
                nodes {
                  rating
                  score
                  project {
                    id
                    name
                  }
                }
              }
            }
          }
        GRAPHQL
      )

      post_graphql(risk_score_query, current_user: attacker)

      expect(response).to have_gitlab_http_status(:ok)

      by_project_nodes = security_metrics_data&.dig('riskScore', 'byProject', 'nodes') || []
      exposed_project_ids = by_project_nodes.filter_map { |node| node['project']&.dig('id') }

      expect(exposed_project_ids).not_to include(private_project.to_global_id.to_s)
    end
  end

  describe 'when security_dashboard feature is not licensed' do
    before_all do
      group.add_maintainer(current_user)
    end

    it 'returns null for security metrics' do
      stub_licensed_features(security_dashboard: false)

      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil
      expect(security_metrics_data).to be_nil
    end
  end

  describe 'when group is private and user is not a member' do
    let_it_be(:private_group) { create(:group, :private) }
    let_it_be(:private_project) { create(:project, :private, group: private_group) }

    it 'returns null group' do
      post_graphql(query(group_path: private_group.full_path), current_user: current_user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil
      expect(graphql_data['group']).to be_nil
    end
  end

  describe 'N+1 query checks' do
    let_it_be(:vulnerability_a) { create(:vulnerability, :critical, :with_read, project: project_1) }
    let_it_be(:vulnerability_b) { create(:vulnerability, :high, :with_read, project: project_2) }

    before_all do
      group.add_maintainer(current_user)
    end

    it 'avoids N+1 queries when requesting vulnerabilities per severity' do
      simple_query = graphql_query_for(
        'group',
        { 'fullPath' => group.full_path },
        <<~GRAPHQL
          securityMetrics {
            vulnerabilitiesPerSeverity {
              critical { count }
              high { count }
              medium { count }
              low { count }
            }
          }
        GRAPHQL
      )

      post_graphql(simple_query, current_user: current_user)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        post_graphql(simple_query, current_user: current_user)
      end

      new_project = create(:project, :public, group: group)
      create_list(:vulnerability, 3, :medium, :with_read, project: new_project)

      expect do
        post_graphql(simple_query, current_user: current_user)
      end.not_to exceed_query_limit(control).allow_skip_cache_inconsistency.with_threshold(2)
    end
  end

  describe 'authorization for nested project traversal via risk score' do
    let_it_be(:parent_group) { create(:group, :public) }
    let_it_be(:child_group) { create(:group, :public, parent: parent_group) }
    let_it_be(:child_project) { create(:project, :public, group: child_group) }
    let_it_be(:private_parent_project) do
      create(:project, :private, group: parent_group, description: 'secret parent project')
    end

    let_it_be(:public_parent_project) { create(:project, :public, group: parent_group) }
    let_it_be(:traversal_user) { create(:user, developer_of: child_group) }

    let(:risk_score_traversal_query) do
      graphql_query_for(
        'group',
        { 'fullPath' => child_group.full_path },
        <<~GRAPHQL
          securityMetrics {
            riskScore {
              byProject {
                nodes {
                  score
                  project {
                    name
                    group {
                      parent {
                        projects {
                          nodes {
                            name
                            description
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        GRAPHQL
      )
    end

    before do
      stub_licensed_features(security_dashboard: true)

      allow_next_instance_of(::Resolvers::Security::RiskScoreResolver) do |resolver|
        allow(resolver).to receive(:resolve).and_return(
          {
            score: 5.0,
            rating: 'medium',
            by_project: [
              {
                rating: 'medium',
                score: 5.0,
                project: child_project
              }
            ]
          }
        )
      end
    end

    context 'when queried by a user who is only a member of the child group' do
      it 'does not expose private projects in parent group' do
        post_graphql(risk_score_traversal_query, current_user: traversal_user)

        parent_project_names = parent_project_names_from_response

        expect(parent_project_names).to include(public_parent_project.name)
        expect(parent_project_names).not_to include(private_parent_project.name)
      end
    end

    context 'when queried by a user who is a member of the parent group' do
      let_it_be(:parent_group_developer) { create(:user, developer_of: parent_group) }

      it 'returns private projects in parent group' do
        post_graphql(risk_score_traversal_query, current_user: parent_group_developer)

        parent_project_names = parent_project_names_from_response

        expect(parent_project_names).to include(public_parent_project.name, private_parent_project.name)
      end
    end

    def parent_project_names_from_response
      by_project_nodes = graphql_dig_at(
        graphql_data, :group, :security_metrics, :risk_score, :by_project, :nodes
      )

      parent_projects = graphql_dig_at(
        by_project_nodes&.first, :project, :group, :parent, :projects, :nodes
      )
      parent_projects&.pluck('name') || []
    end
  end

  describe 'argument validation' do
    before_all do
      group.add_maintainer(current_user)
    end

    context 'with invalid date range' do
      it 'returns error when start date is after end date' do
        invalid_query = graphql_query_for(
          'group',
          { 'fullPath' => group.full_path },
          <<~GRAPHQL
            securityMetrics {
              vulnerabilitiesOverTime(startDate: "2023-12-31", endDate: "2023-01-01") {
                nodes {
                  date
                  count
                }
              }
            }
          GRAPHQL
        )

        post_graphql(invalid_query, current_user: current_user)

        expect(graphql_errors).to be_present
        expect(graphql_errors.first['message']).to match(/start date.*end date/i)
      end

      it 'returns error when date range exceeds maximum' do
        start_date = 2.years.ago(Time.zone.now).to_date
        end_date = Time.zone.now.to_date

        invalid_query = graphql_query_for(
          'group',
          { 'fullPath' => group.full_path },
          <<~GRAPHQL
            securityMetrics {
              vulnerabilitiesOverTime(startDate: "#{start_date.iso8601}", endDate: "#{end_date.iso8601}") {
                nodes {
                  date
                  count
                }
              }
            }
          GRAPHQL
        )

        post_graphql(invalid_query, current_user: current_user)

        expect(graphql_errors).to be_present
        expect(graphql_errors.first['message']).to match(/date range.*days/i)
      end
    end

    context 'with too many security attribute filters' do
      let(:max_filters) { Resolvers::Security::SecurityMetricsResolver::MAX_ATTRIBUTE_FILTERS }

      before do
        allow_next_instance_of(::Search::AdvancedFinders::Security::Vulnerability::CountBySeverityFinder) do |finder|
          allow(finder).to receive(:execute).and_return({})
        end
      end

      def security_metrics_query(filter_count)
        filters = Array.new(filter_count) do |index|
          gid = "gid://gitlab/Security::Attribute/#{index + 1}"
          %({ operator: IS_ONE_OF, attributes: ["#{gid}"] })
        end

        graphql_query_for(
          'group',
          { 'fullPath' => group.full_path },
          <<~GRAPHQL
            securityMetrics(securityAttributesFilters: [#{filters.join(', ')}]) {
              vulnerabilitiesPerSeverity {
                critical { count }
              }
            }
          GRAPHQL
        )
      end

      it 'rejects the request when the filter count exceeds the limit', :aggregate_failures do
        post_graphql(security_metrics_query(max_filters + 1), current_user: current_user)

        expect(graphql_errors).to be_present
        expect(graphql_errors.first['message']).to match(/is too long \(maximum is #{max_filters}\)/)
      end

      it 'accepts the filter count when at the limit', :aggregate_failures do
        post_graphql(security_metrics_query(max_filters), current_user: current_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_errors).to be_nil
      end
    end
  end
end
