# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Re-evaluating security policies for a merge request', feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }

  let(:mutation) do
    graphql_mutation(
      :merge_request_resync_security_policies,
      { project_path: project.full_path, iid: merge_request.iid.to_s },
      <<~FIELDS
        errors
        mergeRequest { iid }
      FIELDS
    )
  end

  def mutation_response
    graphql_mutation_response(:merge_request_resync_security_policies)
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)

    # Default to not throttled so unrelated examples are unaffected by shared
    # rate-limiter state; the throttling context overrides this for its scope.
    allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_call_original
    allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
      .with(:merge_request_resync_security_policies, scope: merge_request)
      .and_return(false)
  end

  context 'when the user can administer the merge request' do
    let_it_be(:current_user) { create(:user, maintainer_of: project) }

    it 'schedules re-evaluation of the security policies and returns no errors', :aggregate_failures do
      expect_next_found_instance_of(MergeRequest) do |mr|
        expect(mr).to receive(:schedule_policy_synchronization)
      end

      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['mergeRequest']['iid']).to eq(merge_request.iid.to_s)
    end

    context 'when the merge request was re-evaluated too recently' do
      before do
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
          .with(:merge_request_resync_security_policies, scope: merge_request)
          .and_return(true)
      end

      it 'does not schedule re-evaluation and returns a rate-limit error' do
        expect_next_found_instance_of(MergeRequest) do |mr|
          expect(mr).not_to receive(:schedule_policy_synchronization)
        end

        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors'])
          .to contain_exactly('This merge request was re-evaluated recently. Please try again in a minute.')
      end
    end
  end

  context 'when the user cannot administer the merge request' do
    let_it_be(:current_user) { create(:user, guest_of: project) }

    it 'does not schedule re-evaluation and returns a top-level authorization error' do
      expect(MergeRequest).not_to receive(:find_by_id)

      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to include(
        a_hash_including('message' => Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR)
      )
    end
  end

  context 'when the merge request does not exist' do
    let_it_be(:current_user) { create(:user, maintainer_of: project) }

    let(:mutation) do
      graphql_mutation(
        :merge_request_resync_security_policies,
        { project_path: project.full_path, iid: non_existing_record_iid.to_s },
        'errors'
      )
    end

    it 'returns a top-level authorization error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to include(
        a_hash_including('message' => Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR)
      )
    end
  end

  describe 'rate limit scoping', :clean_gitlab_redis_rate_limiting, :freeze_time do
    let_it_be(:mr_a) { create(:merge_request, source_project: project, source_branch: 'rate-limit-a') }
    let_it_be(:mr_b) { create(:merge_request, source_project: project, source_branch: 'rate-limit-b') }

    it 'throttles per merge request, not per instance' do
      limiter = Gitlab::ApplicationRateLimiter
      key = :merge_request_resync_security_policies

      # First re-evaluation of MR A is allowed (threshold is 1 per minute).
      expect(limiter.throttled?(key, scope: mr_a)).to be(false)
      # Second re-evaluation of the SAME MR within the interval is throttled.
      expect(limiter.throttled?(key, scope: mr_a)).to be(true)

      # A different MR keeps its own independent budget: if the limit were
      # per-instance this would already be throttled by the MR A calls above.
      expect(limiter.throttled?(key, scope: mr_b)).to be(false)
      expect(limiter.throttled?(key, scope: mr_b)).to be(true)
    end
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :update_merge_request do
    let(:user) { create(:user, maintainer_of: project) }
    let(:boundary_object) { project }
    let(:mutation) do
      graphql_mutation(
        :merge_request_resync_security_policies,
        { project_path: project.full_path, iid: merge_request.iid.to_s },
        'errors'
      )
    end

    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end
end
