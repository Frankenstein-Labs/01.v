# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "getting a project's linked observability traces", feature_category: :observability do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:trace) do
    create(:observability_traces_issues_connection,
      trace_identifier: 'test1',
      issue: create(:issue, project: project)
    )
  end

  let_it_be(:trace2) { create(:observability_traces_issues_connection, issue: create(:issue)) }

  let(:fields) do
    <<~QUERY
      nodes {
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
      query_graphql_field('observabilityTracesLinks', params, fields)
    )
  end

  let(:params) { {} }

  let(:traces) do
    graphql_data.dig('project', 'observabilityTracesLinks', 'nodes')
  end

  before_all do
    project.add_reporter(current_user)
  end

  context 'when observability features are available' do
    before do
      stub_licensed_features(observability: true)
    end

    context 'when current_user is not a project member' do
      it 'returns all trace connections for a project' do
        post_graphql(query, current_user: create(:user))

        expect(traces).to be_nil
      end
    end

    context 'when no parameters are passed' do
      it 'returns all trace connections for a project' do
        post_graphql(query, current_user: current_user)

        expect(traces.size).to eq(1)
      end
    end

    context 'when trace_identifier is passed' do
      let(:params) { { trace_identifier: 'test1' } }

      it 'returns the correct trace' do
        post_graphql(query, current_user: current_user)

        expect(traces.count).to eq(1)
        expect(traces.first).to eq({
          issue: {
            title: trace.issue.title,
            webUrl: Gitlab::UrlBuilder.build(trace.issue)
          }.stringify_keys,
          traceIdentifier: "test1"
        }.stringify_keys)
      end
    end

    context 'when a non-existent trace_identifier is passed' do
      let(:params) { { trace_identifier: 'aaaaaaaaaa' } }

      it 'returns the correct trace' do
        post_graphql(query, current_user: current_user)

        expect(traces.count).to eq(0)
      end
    end
  end

  context 'when observability features are not licensed' do
    before do
      stub_licensed_features(observability: false)
    end

    it 'returns no results' do
      post_graphql(query, current_user: current_user)

      expect(traces).to be_nil
    end
  end

  context 'when observability features are not enabled' do
    before do
      stub_licensed_features(observability: true)
      stub_feature_flags(observability_features: false)
    end

    it 'returns no results' do
      post_graphql(query, current_user: current_user)

      expect(traces).to be_nil
    end
  end
end
