# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::API::Search::SemanticCodeSearch, :api, :clean_gitlab_redis_rate_limiting, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :private) }

  let_it_be(:api_token) do
    create(:personal_access_token, scopes: %w[api], user: user)
  end

  let_it_be(:ai_workflows_token) do
    create(:oauth_access_token, scopes: [:ai_workflows], resource_owner: user)
  end

  let_it_be(:read_user_token) do
    create(:personal_access_token, scopes: %w[read_user], user: user)
  end

  let(:path) { "/projects/#{project.id}/search/semantic" }
  let(:params) { { q: 'authentication logic' } }
  let(:hits) do
    [
      {
        'path' => 'app/models/user.rb',
        'content' => 'def authenticate',
        'blob_id' => 'abc123',
        'start_line' => 42,
        'file_url' => "https://gitlab.com/#{project.full_path}/-/blob/main/app/models/user.rb",
        'score' => 0.95
      },
      {
        'path' => 'app/models/user.rb',
        'content' => 'def verify_token',
        'blob_id' => 'abc123',
        'start_line' => 80,
        'file_url' => "https://gitlab.com/#{project.full_path}/-/blob/main/app/models/user.rb",
        'score' => 0.88
      },
      {
        'path' => 'lib/auth/middleware.rb',
        'content' => 'def call(env)',
        'blob_id' => 'def456',
        'start_line' => 10,
        'file_url' => "https://gitlab.com/#{project.full_path}/-/blob/main/lib/auth/middleware.rb",
        'score' => 0.72
      }
    ]
  end

  let(:success_result) { ::Ai::ActiveContext::Queries::Result.success(hits) }
  let(:error_result) do
    ::Ai::ActiveContext::Queries::Result.no_embeddings_error(
      error_detail: 'initial indexing is still ongoing, try again in a few minutes'
    )
  end

  before_all do
    project.add_developer(user)
  end

  before do
    allow(::Ai::ActiveContext::Queries::Code).to receive(:available?).and_return(true)
    allow_next_instance_of(::Ai::ActiveContext::Queries::Code) do |instance|
      allow(instance).to receive(:filter).and_return(success_result)
    end
  end

  describe 'GET /projects/:id/search/semantic' do
    subject(:get_api) { get api(path, personal_access_token: api_token), params: params }

    context 'when user is not authenticated' do
      it 'returns 401' do
        get api(path), params: params

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when token lacks sufficient scope' do
      it 'returns 403 for read_user scope' do
        get api(path, personal_access_token: read_user_token), params: params

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'allows ai_workflows scope' do
        get api(path, oauth_access_token: ai_workflows_token), params: params

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when project does not exist' do
      it 'returns 404' do
        get api("/projects/#{non_existing_record_id}/search/semantic",
          personal_access_token: api_token), params: params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user lacks read_code permission' do
      let_it_be(:non_member) { create(:user) }
      let_it_be(:non_member_token) { create(:personal_access_token, scopes: %w[api], user: non_member) }

      it 'returns 404 for non-member on private project' do
        get api(path, personal_access_token: non_member_token), params: params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when semantic search service is unavailable' do
      before do
        allow(::Ai::ActiveContext::Queries::Code).to receive(:new)
          .and_raise(::Ai::ActiveContext::Queries::Code::NotAvailable)
      end

      it 'returns 404' do
        get_api

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when project has no embeddings' do
      before do
        allow_next_instance_of(::Ai::ActiveContext::Queries::Code) do |instance|
          allow(instance).to receive(:filter).and_return(error_result)
        end
      end

      it 'returns 422 with error message' do
        get_api

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response['message']).to include('has no embeddings')
      end

      it 'does not trigger ad-hoc indexing' do
        expect(::Ai::ActiveContext::Code::AdHocIndexingWorker).not_to receive(:perform_async)

        get_api
      end
    end

    context 'when a file is excluded from Duo context' do
      before do
        exclusion_result = ServiceResponse.success(
          payload: [
            { path: 'app/models/user.rb', excluded: true },
            { path: 'lib/auth/middleware.rb', excluded: false }
          ]
        )
        allow_next_instance_of(::Ai::FileExclusionService) do |svc|
          allow(svc).to receive(:execute).and_return(exclusion_result)
        end
      end

      it 'omits excluded files from results' do
        get_api

        expect(response).to have_gitlab_http_status(:ok)
        paths = json_response['results'].pluck('path')
        expect(paths).to contain_exactly('lib/auth/middleware.rb')
        expect(paths).not_to include('app/models/user.rb')
      end
    end

    context 'with valid request' do
      it_behaves_like 'authorizing granular token permissions', :read_code do
        let(:boundary_object) { project }
        let(:request) { get api(path, personal_access_token: pat), params: params }
      end

      it 'returns 200 with grouped results and confidence' do
        get_api

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include('confidence', 'results')
        expect(json_response['results']).to be_an(Array)
      end

      it 'groups multiple hits from the same file' do
        get_api

        user_rb = json_response['results'].find { |r| r['path'] == 'app/models/user.rb' }
        expect(user_rb).to include('path' => 'app/models/user.rb', 'blob_id' => 'abc123')
        expect(user_rb['snippet_ranges'].length).to eq(2)
        expect(user_rb['snippet_ranges'].first).to include(
          'start_line' => 42,
          'content' => 'def authenticate',
          'score' => 0.95
        )
      end

      it 'returns separate grouped result for each distinct file' do
        get_api

        paths = json_response['results'].pluck('path')
        expect(paths).to contain_exactly('app/models/user.rb', 'lib/auth/middleware.rb')
      end

      it 'includes a confidence level' do
        get_api

        expect(json_response['confidence']).to be_in(%w[high medium low unknown])
      end

      it 'tracks internal event' do
        expect { get_api }.to trigger_internal_events('search_code_with_semantic_search').with(
          user: user, project: project, namespace: project.root_namespace,
          category: 'InternalEventTracking'
        )
      end

      it 'includes file_url in each result' do
        get_api

        result = json_response['results'].first
        expect(result).to have_key('file_url')
        expect(result['file_url']).to be_a(String)
      end

      it 'passes q parameter to the service as search_term' do
        expect_next_instance_of(::Ai::ActiveContext::Queries::Code,
          search_term: 'authentication logic', user: user) do |instance|
          expect(instance).to receive(:filter).with(
            hash_including(
              project_or_id: project,
              path: nil,
              knn_count: 64,
              limit: 20,
              exclude_fields: %w[id source type embeddings_v1 reindexing],
              extract_source_segments: true,
              build_file_url: true
            )
          ).and_return(success_result)
        end

        get_api
      end
    end

    context 'with optional parameters' do
      let(:params) { { q: 'auth', directory_path: 'app/models', knn: 5, limit: 3 } }

      it 'forwards optional params to the service' do
        expect_next_instance_of(::Ai::ActiveContext::Queries::Code,
          search_term: 'auth', user: user) do |instance|
          expect(instance).to receive(:filter).with(
            hash_including(path: 'app/models', knn_count: 5, limit: 3)
          ).and_return(success_result)
        end

        get_api

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'with invalid parameters' do
      it 'returns 400 when q is missing' do
        get api(path, personal_access_token: api_token), params: {}

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when q is blank' do
        get api(path, personal_access_token: api_token), params: { q: '' }

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when knn is out of range' do
        get api(path, personal_access_token: api_token), params: params.merge(knn: 0)

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when limit exceeds maximum' do
        get api(path, personal_access_token: api_token), params: params.merge(limit: 101)

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when directory_path starts with /' do
        get api(path, personal_access_token: api_token), params: params.merge(directory_path: '/app/models')

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when directory_path contains .. segments' do
        get api(path, personal_access_token: api_token), params: params.merge(directory_path: 'app/../etc')

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when rate limited', :freeze_time do
      before do
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_call_original
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
          .with(:semantic_search_rate_limit, scope: [user])
          .and_return(true)
      end

      it 'returns 429' do
        get_api

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end
  end
end
