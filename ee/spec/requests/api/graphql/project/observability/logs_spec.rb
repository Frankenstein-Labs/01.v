# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "getting a project's linked observability logs", feature_category: :observability do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:log) { create(:observability_logs_issues_connection, issue: create(:issue, project: project)) }
  let_it_be(:log2) do
    create(:observability_logs_issues_connection, issue: create(:issue, project: project, title: 'title1'))
  end

  let_it_be(:log3) do
    create(:observability_logs_issues_connection,
      issue: create(:issue, project: project, title: 'title2')
    )
  end

  let_it_be(:log4) do
    create(:observability_logs_issues_connection,
      service_name: 'different_name',
      issue: create(:issue, project: project)
    )
  end

  let_it_be(:log5) do
    create(:observability_logs_issues_connection,
      issue: create(:issue, project: project)
    )
  end

  let_it_be(:log_different_project) { create(:observability_logs_issues_connection, issue: create(:issue)) }

  let(:fields) do
    <<~QUERY
      nodes {
        timestamp
        severityNumber
        serviceName
        fingerprint
        traceIdentifier
        issue {
          title
          webUrl
        }
      }
    QUERY
  end

  let(:query) do
    graphql_query_for(
      'project',
      { 'fullPath' => project.full_path },
      query_graphql_field('observabilityLogsLinks', params, fields)
    )
  end

  let(:params) { {} }

  let(:logs) do
    graphql_data.dig('project', 'observabilityLogsLinks', 'nodes')
  end

  before_all do
    project.add_reporter(current_user)
  end

  context 'when observability features are available' do
    before do
      stub_licensed_features(observability: true)
    end

    context 'when no parameters are passed' do
      it 'returns all log connections for a project' do
        post_graphql(query, current_user: current_user)

        expect(logs.size).to eq(5)
      end

      it "avoids N+1 database queries", :use_sql_query_cache do
        post_graphql(query, current_user: current_user) # warm up

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        create(:observability_logs_issues_connection, issue: create(:issue, project: project))
        expect do
          post_graphql(query, current_user: current_user)
        end.to issue_same_number_of_queries_as(control).with_threshold(1)
      end
    end

    context 'when some parameters are passed is passed, and others is not' do
      let(:params) { { service_name: "hello-world" } }

      it 'returns an empty collection' do
        post_graphql(query, current_user: current_user)

        expect(logs.count).to be_zero
      end
    end

    context 'when all parameters are passed' do
      let(:params) do
        {
          timestamp: log4.log_timestamp,
          severityNumber: log4.severity_number,
          serviceName: log4.service_name,
          fingerprint: log4.log_fingerprint,
          traceIdentifier: log4.trace_identifier
        }
      end

      it 'returns metrics from the project that match the input parameters' do
        post_graphql(query, current_user: current_user)

        expect(logs.count).to eq(1)
        expect(logs.first).to eq({
          issue: {
            title: log4.issue.title,
            webUrl: Gitlab::UrlBuilder.build(log4.issue)
          }.stringify_keys,
          serviceName: log4.service_name,
          fingerprint: log4.log_fingerprint,
          severityNumber: log4.severity_number,
          timestamp: log4.log_timestamp.iso8601,
          traceIdentifier: log4.trace_identifier
        }.stringify_keys)
      end
    end
  end

  context 'when observability features are not licensed' do
    before do
      stub_licensed_features(observability: false)
    end

    it 'returns no results' do
      post_graphql(query, current_user: current_user)

      expect(logs).to be_nil
    end
  end

  context 'when observability features are not enabled' do
    before do
      stub_licensed_features(observability: true)
      stub_feature_flags(observability_features: false)
    end

    it 'returns no results' do
      post_graphql(query, current_user: current_user)

      expect(logs).to be_nil
    end
  end

  context 'when user is not a project member' do
    let_it_be(:current_user) { create(:user) }

    it 'returns no results' do
      post_graphql(query, current_user: current_user)

      expect(logs).to be_nil
    end
  end
end
