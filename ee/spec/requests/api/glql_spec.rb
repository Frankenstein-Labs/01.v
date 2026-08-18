# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Glql, feature_category: :custom_dashboards_foundation do
  let_it_be(:user) { create(:user) }
  let_it_be(:non_member) { create(:user) }
  let_it_be(:group) { create(:group, name: 'test-group-ee', developers: user) }
  let_it_be(:project) { create(:project, name: 'test-project', path: 'test-project', namespace: group) }

  let_it_be(:analytics_disabled_project) do
    create(:project, namespace: group, analytics_access_level: ProjectFeature::DISABLED)
  end

  let(:endpoint) { '/glql' }

  subject(:glql_request) { post api(endpoint, user), params: params }

  before do
    stub_licensed_features(ai_workflows: true)
  end

  describe 'POST /glql' do
    context 'with analytics mode for code suggestions' do
      let(:glql_yaml) do
        <<~YAML
          query: type = CodeSuggestion and language = "ruby"
          mode: "analytics"
          dimensions: "language"
          metrics: "totalCount, acceptanceRate"
          project: "#{project.full_path}"
        YAML
      end

      let(:params) { { glql_yaml: glql_yaml } }
      let(:analytics_scope_key) { 'project' }

      let(:analytics_nodes) do
        [
          {
            'dimensions' => { 'language' => 'ruby' },
            'totalCount' => 20,
            'acceptanceRate' => 0.85
          }
        ]
      end

      let(:analytics_response) do
        {
          'data' => {
            analytics_scope_key => {
              'analytics' => {
                'duoCodeSuggestions' => {
                  'aggregated' => {
                    'nodes' => analytics_nodes,
                    'pageInfo' => { 'hasNextPage' => false, 'endCursor' => nil }
                  }
                }
              }
            }
          }
        }
      end

      before do
        allow_next_instance_of(Analytics::Glql::QueryService) do |service|
          allow(service).to receive(:execute).and_return(
            data: analytics_response['data'],
            errors: nil,
            complexity_score: 15,
            duration_s: 0.5,
            timeout_occurred: false,
            rate_limited: false
          )
        end
      end

      it 'returns analytics data in the correct format', :aggregate_failures do
        glql_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['success']).to be(true)
        expect(json_response['data']['nodes']).to be_an(Array)
        expect(json_response['data']['nodes'].first).to include(
          'language' => 'ruby',
          'totalCount' => 20,
          'acceptanceRate' => 0.85
        )
        expect(json_response['data']['pageInfo']).to include('hasNextPage' => false)
      end

      context 'when filtering by group' do
        let(:analytics_scope_key) { 'group' }
        let(:glql_yaml) do
          <<~YAML
            query: type = CodeSuggestion and language = "ruby"
            mode: "analytics"
            dimensions: "language"
            metrics: "totalCount, acceptanceRate"
            group: "#{group.full_path}"
          YAML
        end

        it 'allows the query for that group', :aggregate_failures do
          glql_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['success']).to be(true)
        end
      end
    end

    context 'with analytics mode for merge requests' do
      let(:glql_yaml) do
        <<~YAML
          query: type = MergeRequest
          mode: "analytics"
          dimensions: "state, targetBranch"
          metrics: "totalCount, timeToMergeQuantile"
          project: "#{project.full_path}"
        YAML
      end

      let(:params) { { glql_yaml: glql_yaml } }
      let(:analytics_scope_key) { 'project' }

      let(:analytics_nodes) do
        [
          {
            'dimensions' => { 'state' => 'merged', 'targetBranch' => 'main' },
            'totalCount' => 12,
            'timeToMergeQuantile' => 3600
          }
        ]
      end

      let(:analytics_response) do
        {
          'data' => {
            analytics_scope_key => {
              'analytics' => {
                'mergeRequests' => {
                  'aggregated' => {
                    'nodes' => analytics_nodes,
                    'pageInfo' => { 'hasNextPage' => false, 'endCursor' => nil }
                  }
                }
              }
            }
          }
        }
      end

      context 'when the user is authorized' do
        before do
          allow_next_instance_of(Analytics::Glql::QueryService) do |service|
            allow(service).to receive(:execute).and_return(
              data: analytics_response['data'],
              errors: nil,
              complexity_score: 15,
              duration_s: 0.5,
              timeout_occurred: false,
              rate_limited: false
            )
          end
        end

        it 'returns analytics data in the correct format', :aggregate_failures do
          glql_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['success']).to be(true)
          expect(json_response['data']['nodes']).to be_an(Array)
          expect(json_response['data']['nodes'].first).to include(
            'state' => 'merged',
            'targetBranch' => 'main',
            'totalCount' => 12,
            'timeToMergeQuantile' => 3600
          )
          expect(json_response['data']['pageInfo']).to include('hasNextPage' => false)
        end

        it 'returns field metadata including default quantile parameter', :aggregate_failures do
          glql_request

          fields = json_response['fields'].index_by { |field| field['key'] }

          expect(fields.keys).to match_array(%w[state targetBranch totalCount timeToMergeQuantile])
          expect(fields['state']).to include('type' => 'dimension')
          expect(fields['timeToMergeQuantile']).to include(
            'type' => 'metric',
            'parameters' => { 'quantile' => '0.5' }
          )
        end

        context 'when filtering by group' do
          let(:analytics_scope_key) { 'group' }
          let(:glql_yaml) do
            <<~YAML
              query: type = MergeRequest
              mode: "analytics"
              dimensions: "state, targetBranch"
              metrics: "totalCount, timeToMergeQuantile"
              group: "#{group.full_path}"
            YAML
          end

          it 'allows the query for that group', :aggregate_failures do
            glql_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['success']).to be(true)
          end
        end
      end

      # QueryService is intentionally not stubbed below so the real GraphQL
      # authorization path runs.
      context 'when the user is a member but the analytics feature is disabled' do
        let(:glql_yaml) do
          <<~YAML
            query: type = MergeRequest
            mode: "analytics"
            dimensions: "state, targetBranch"
            metrics: "totalCount, timeToMergeQuantile"
            project: "#{analytics_disabled_project.full_path}"
          YAML
        end

        it 'denies access without leaking data', :aggregate_failures do
          glql_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response).to eq(
            'error' => "The following sources are not accessible: #{analytics_disabled_project.full_path}"
          )
        end
      end

      context 'when the user is not a member of the private project' do
        subject(:glql_request) { post api(endpoint, non_member), params: params }

        it 'denies access without revealing project existence', :aggregate_failures do
          glql_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response).to eq(
            'error' => 'Error: Project does not exist or you do not have access to it'
          )
        end
      end

      context 'when unauthenticated' do
        subject(:glql_request) { post api(endpoint), params: params }

        it 'denies access without revealing project existence', :aggregate_failures do
          glql_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response).to eq(
            'error' => 'Error: Project does not exist or you do not have access to it'
          )
        end
      end
    end

    context 'with analytics mode for AI usage events' do
      let(:glql_yaml) do
        <<~YAML
          query: type = AiUsageEvent
          mode: "analytics"
          dimensions: "feature, timestamp"
          metrics: "totalCount, usersCount"
          group: "#{group.full_path}"
        YAML
      end

      let(:params) { { glql_yaml: glql_yaml } }
      let(:analytics_scope_key) { 'group' }

      let(:analytics_nodes) do
        [
          {
            'dimensions' => { 'feature' => 'code_suggestions', 'timestamp' => '2026-07-27' },
            'totalCount' => 42,
            'usersCount' => 7
          }
        ]
      end

      let(:analytics_response) do
        {
          'data' => {
            analytics_scope_key => {
              'analytics' => {
                'duoUsageEvents' => {
                  'aggregated' => {
                    'nodes' => analytics_nodes,
                    'pageInfo' => { 'hasNextPage' => false, 'endCursor' => nil }
                  }
                }
              }
            }
          }
        }
      end

      context 'when the user is authorized' do
        before do
          allow_next_instance_of(Analytics::Glql::QueryService) do |service|
            allow(service).to receive(:execute).and_return(
              data: analytics_response['data'],
              errors: nil,
              complexity_score: 15,
              duration_s: 0.5,
              timeout_occurred: false,
              rate_limited: false
            )
          end
        end

        it 'returns analytics data in the correct format', :aggregate_failures do
          glql_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['success']).to be(true)
          expect(json_response['data']['nodes']).to be_an(Array)
          expect(json_response['data']['nodes'].first).to include(
            'feature' => 'code_suggestions',
            'timestamp' => '2026-07-27',
            'totalCount' => 42,
            'usersCount' => 7
          )
          expect(json_response['data']['pageInfo']).to include('hasNextPage' => false)
        end

        it 'returns field metadata including default granularity parameter', :aggregate_failures do
          glql_request

          fields = json_response['fields'].index_by { |field| field['key'] }

          expect(fields.keys).to match_array(%w[feature timestamp totalCount usersCount])
          expect(fields['totalCount']).to include('type' => 'metric')
          expect(fields['timestamp']).to include(
            'type' => 'dimension',
            'parameters' => { 'granularity' => 'weekly' }
          )
        end

        context 'when filtering by project' do
          let(:analytics_scope_key) { 'project' }
          let(:glql_yaml) do
            <<~YAML
              query: type = AiUsageEvent
              mode: "analytics"
              dimensions: "feature, timestamp"
              metrics: "totalCount, usersCount"
              project: "#{project.full_path}"
            YAML
          end

          it 'allows the query for that project', :aggregate_failures do
            glql_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['success']).to be(true)
          end
        end
      end

      # QueryService is intentionally not stubbed below so the real GraphQL
      # authorization path runs. Missing, out-of-scope, and unauthorized
      # sources are reported identically by the aggregation engine resolver.
      # The group is public, so even anonymous requests resolve `group(fullPath:)`
      # and reach the engine resolver, which denies all four cases below with the
      # same message when the `read_pro_ai_analytics` ability check fails.
      context 'when authorization fails' do
        let(:denial_body) do
          { 'error' => "The following sources are not accessible: #{group.full_path}" }
        end

        shared_examples 'denies access to AI usage analytics' do
          it 'returns an error without leaking data', :aggregate_failures do
            glql_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response).to eq(denial_body)
          end
        end

        context 'when a guest lacks the required ability despite licensing' do
          let_it_be(:guest) { create(:user, guest_of: group) }

          subject(:glql_request) { post api(endpoint, guest), params: params }

          before do
            stub_licensed_features(ai_workflows: true, ai_analytics: true)
          end

          it_behaves_like 'denies access to AI usage analytics'
        end

        context 'when the ai_analytics feature is not licensed' do
          it_behaves_like 'denies access to AI usage analytics'
        end

        context 'when the user is not a member' do
          subject(:glql_request) { post api(endpoint, non_member), params: params }

          it_behaves_like 'denies access to AI usage analytics'
        end

        context 'when unauthenticated' do
          subject(:glql_request) { post api(endpoint), params: params }

          it_behaves_like 'denies access to AI usage analytics'
        end
      end
    end

    context 'with analytics mode for pipelines' do
      let(:glql_yaml) do
        <<~YAML
          query: type = Pipeline
          mode: "analytics"
          dimensions: "ref, status"
          metrics: "totalCount, durationQuantile"
          project: "#{project.full_path}"
        YAML
      end

      let(:params) { { glql_yaml: glql_yaml } }
      let(:analytics_scope_key) { 'project' }

      let(:analytics_nodes) do
        [
          {
            'dimensions' => { 'ref' => 'main', 'status' => 'success' },
            'totalCount' => 25,
            'durationQuantile' => 540
          }
        ]
      end

      let(:analytics_response) do
        {
          'data' => {
            analytics_scope_key => {
              'analytics' => {
                'pipelines' => {
                  'aggregated' => {
                    'nodes' => analytics_nodes,
                    'pageInfo' => { 'hasNextPage' => false, 'endCursor' => nil }
                  }
                }
              }
            }
          }
        }
      end

      context 'when the user is authorized' do
        before do
          allow_next_instance_of(Analytics::Glql::QueryService) do |service|
            allow(service).to receive(:execute).and_return(
              data: analytics_response['data'],
              errors: nil,
              complexity_score: 15,
              duration_s: 0.5,
              timeout_occurred: false,
              rate_limited: false
            )
          end
        end

        it 'returns analytics data in the correct format', :aggregate_failures do
          glql_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['success']).to be(true)
          expect(json_response['data']['nodes']).to be_an(Array)
          expect(json_response['data']['nodes'].first).to include(
            'ref' => 'main',
            'status' => 'success',
            'totalCount' => 25,
            'durationQuantile' => 540
          )
          expect(json_response['data']['pageInfo']).to include('hasNextPage' => false)
        end

        it 'returns field metadata including default quantile parameter', :aggregate_failures do
          glql_request

          fields = json_response['fields'].index_by { |field| field['key'] }

          expect(fields.keys).to match_array(%w[ref status totalCount durationQuantile])
          expect(fields['ref']).to include('type' => 'dimension')
          expect(fields['durationQuantile']).to include(
            'type' => 'metric',
            'parameters' => { 'quantile' => '0.95' }
          )
        end

        context 'when filtering by group' do
          let(:analytics_scope_key) { 'group' }
          let(:glql_yaml) do
            <<~YAML
              query: type = Pipeline
              mode: "analytics"
              dimensions: "ref, status"
              metrics: "totalCount, durationQuantile"
              group: "#{group.full_path}"
            YAML
          end

          it 'allows the query for that group', :aggregate_failures do
            glql_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['success']).to be(true)
          end
        end
      end

      # QueryService is intentionally not stubbed below so the real GraphQL
      # authorization path runs.
      context 'when the user is a member but the analytics feature is disabled' do
        let(:glql_yaml) do
          <<~YAML
            query: type = Pipeline
            mode: "analytics"
            dimensions: "ref, status"
            metrics: "totalCount, durationQuantile"
            project: "#{analytics_disabled_project.full_path}"
          YAML
        end

        it 'denies access without leaking data', :aggregate_failures do
          glql_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response).to eq(
            'error' => "The following sources are not accessible: #{analytics_disabled_project.full_path}"
          )
        end
      end

      # Guests can see the private project, so `project(fullPath:)` resolves and
      # the engine resolver denies with the sources message because
      # `read_ci_cd_analytics` requires at least the Reporter role.
      context 'when the user is a guest member of the private project' do
        let_it_be(:guest) { create(:user, guest_of: project) }

        subject(:glql_request) { post api(endpoint, guest), params: params }

        it 'denies access without leaking data', :aggregate_failures do
          glql_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response).to eq(
            'error' => "The following sources are not accessible: #{project.full_path}"
          )
        end
      end

      # In the two contexts below, the private project fails to resolve before
      # the ability check runs, so the response carries the gem's transform
      # message rather than the engine resolver's sources message.
      context 'when the user is not a member of the private project' do
        subject(:glql_request) { post api(endpoint, non_member), params: params }

        it 'denies access without revealing project existence', :aggregate_failures do
          glql_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response).to eq(
            'error' => 'Error: Project does not exist or you do not have access to it'
          )
        end
      end

      context 'when unauthenticated' do
        subject(:glql_request) { post api(endpoint), params: params }

        it 'denies access without revealing project existence', :aggregate_failures do
          glql_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response).to eq(
            'error' => 'Error: Project does not exist or you do not have access to it'
          )
        end
      end

      # Unlike the private project above, the group is public, so
      # `group(fullPath:)` resolves even for anonymous requests and both
      # contexts below reach the engine resolver, which denies with the
      # sources message when the `read_ci_cd_analytics` ability check fails.
      context 'when the group-scoped query is not authorized' do
        let(:glql_yaml) do
          <<~YAML
            query: type = Pipeline
            mode: "analytics"
            dimensions: "ref, status"
            metrics: "totalCount, durationQuantile"
            group: "#{group.full_path}"
          YAML
        end

        shared_examples 'denies access to group pipeline analytics' do
          it 'returns an error without leaking data', :aggregate_failures do
            glql_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response).to eq(
              'error' => "The following sources are not accessible: #{group.full_path}"
            )
          end
        end

        context 'when the user is not a member' do
          subject(:glql_request) { post api(endpoint, non_member), params: params }

          it_behaves_like 'denies access to group pipeline analytics'
        end

        context 'when unauthenticated' do
          subject(:glql_request) { post api(endpoint), params: params }

          it_behaves_like 'denies access to group pipeline analytics'
        end
      end
    end
  end
end
