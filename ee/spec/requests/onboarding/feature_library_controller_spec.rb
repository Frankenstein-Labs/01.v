# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::FeatureLibraryController, :saas, feature_category: :onboarding do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, developers: user) }
  let_it_be(:gitlab_subscription) do
    create(:gitlab_subscription, :active_trial, :ultimate_trial, namespace: group, trial_ends_on: Date.tomorrow)
  end

  describe 'GET /-/onboarding/feature_library/ai_search', :clean_gitlab_redis_rate_limiting do
    before do
      sign_in(user)
    end

    context 'when AI search is available for the namespace' do
      before do
        allow_next_instance_of(Gitlab::Llm::AiGateway::Completions::FeatureDiscoverySearch) do |completion|
          allow(completion).to receive(:execute).and_return(%w[group_merge_request_list])
        end
      end

      it 'returns the AI Gateway matched ids and ai_search_available: true', :aggregate_failures do
        get onboarding_feature_library_ai_search_path,
          params: { query: 'completelyrandom', panel: 'group', resource_id: group.id }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['ids']).to eq(%w[group_merge_request_list])
        expect(json_response['ai_search_available']).to be(true)
      end
    end

    context 'when the query exceeds MAX_QUERY_LENGTH' do
      let(:long_query) { 'x' * (described_class::MAX_QUERY_LENGTH + 50) }

      before do
        allow_next_instance_of(Gitlab::Llm::AiGateway::Completions::FeatureDiscoverySearch) do |completion|
          allow(completion).to receive(:execute).and_return([])
        end
      end

      it 'truncates the query before handing it to the AI Gateway completion' do
        expect(Gitlab::Llm::AiGateway::Completions::FeatureDiscoverySearch)
          .to receive(:new)
          .with(anything, anything, a_hash_including(query: 'x' * described_class::MAX_QUERY_LENGTH))

        get onboarding_feature_library_ai_search_path,
          params: { query: long_query, panel: 'group', resource_id: group.id }

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when AI search is not available for the namespace' do
      it 'returns an empty ids array and ai_search_available: false without calling the AI Gateway',
        :aggregate_failures do
        expect(Gitlab::Llm::AiGateway::Completions::FeatureDiscoverySearch).not_to receive(:new)

        get onboarding_feature_library_ai_search_path, params: { query: 'completelyrandom', panel: 'group' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['ids']).to eq([])
        expect(json_response['ai_search_available']).to be(false)
      end
    end

    context 'when the feature_discovery_gemini_search flag is disabled' do
      before do
        stub_feature_flags(feature_discovery_gemini_search: false)
      end

      it 'returns 404' do
        get onboarding_feature_library_ai_search_path,
          params: { query: 'completelyrandom', panel: 'group', resource_id: group.id }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the rate limit is exceeded' do
      before do
        allow(Gitlab::ApplicationRateLimiter)
          .to receive(:throttled_request?)
          .with(anything, anything, :feature_library_ai_search, scope: user)
          .and_return(true)
      end

      it 'returns 429 with a JSON error message', :aggregate_failures do
        get onboarding_feature_library_ai_search_path,
          params: { query: 'completelyrandom', panel: 'group', resource_id: group.id }

        expect(response).to have_gitlab_http_status(:too_many_requests)
        expect(json_response['error']).to be_present
      end
    end
  end
end
