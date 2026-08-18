# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GraphQL requests for project pipeline subscriptions', feature_category: :continuous_integration do
  include GraphqlHelpers

  let_it_be(:downstream) { create(:project) }
  let_it_be(:upstream) { create(:project, :public) }

  let_it_be(:upstream_maintainer) { create(:user, maintainer_of: upstream) }
  let_it_be(:downstream_maintainer) { create(:user, maintainer_of: downstream) }

  let_it_be(:subscription) do
    create(:ci_subscriptions_project, downstream_project: downstream, upstream_project: upstream)
  end

  describe 'ci_downstream_project_subscriptions' do
    let(:query) do
      <<~GRAPHQL
      query($fullPath: ID!) {
        project(fullPath: $fullPath) {
          ciDownstreamProjectSubscriptions {
            count
            nodes {
              upstreamProject { id }
              downstreamProject { id }
            }
          }
        }
      }
      GRAPHQL
    end

    before do
      post_graphql(query, current_user: upstream_maintainer, variables: { full_path: upstream.full_path })
    end

    it_behaves_like 'a working graphql query', :use_clean_rails_memory_store_caching, :request_store

    it 'finds the subscription' do
      expect(graphql_data.dig('project', 'ciDownstreamProjectSubscriptions', 'nodes', 0, 'upstreamProject', 'id')).to(
        eq(upstream.to_global_id.to_s)
      )
      expect(graphql_data.dig('project', 'ciDownstreamProjectSubscriptions', 'nodes', 0, 'downstreamProject', 'id')).to(
        eq(downstream.to_global_id.to_s)
      )
    end

    context "with unauthorized user(project developer)" do
      let(:developer) { create(:user, developer_of: upstream) }

      before do
        post_graphql(query, current_user: developer, variables: { full_path: upstream.full_path })
      end

      it_behaves_like 'a working graphql query', :use_clean_rails_memory_store_caching, :request_store

      it 'returns no subscriptiona' do
        expect(graphql_data_at(:project, :ciDownstreamProjectSubscriptions, :nodes)).to be_empty
      end
    end
  end

  describe 'ci_upstream_project_subscriptions' do
    let(:query) do
      <<~GRAPHQL
      query($fullPath: ID!) {
        project(fullPath: $fullPath) {
          ciUpstreamProjectSubscriptions {
            count
            nodes {
              upstreamProject { id }
              downstreamProject { id }
            }
          }
        }
      }
      GRAPHQL
    end

    before do
      post_graphql(query, current_user: downstream_maintainer, variables: { full_path: downstream.full_path })
    end

    it_behaves_like 'a working graphql query', :use_clean_rails_memory_store_caching, :request_store

    it 'finds the subscription' do
      expect(graphql_data.dig('project', 'ciUpstreamProjectSubscriptions', 'nodes', 0, 'upstreamProject', 'id')).to(
        eq(upstream.to_global_id.to_s)
      )
      expect(graphql_data.dig('project', 'ciUpstreamProjectSubscriptions', 'nodes', 0, 'downstreamProject', 'id')).to(
        eq(downstream.to_global_id.to_s)
      )
    end

    context "with unauthorized user(project developer)" do
      let(:developer) { create(:user, developer_of: downstream) }

      before do
        post_graphql(query, current_user: developer, variables: { full_path: downstream.full_path })
      end

      it_behaves_like 'a working graphql query', :use_clean_rails_memory_store_caching, :request_store

      it 'returns no subscriptiona' do
        expect(graphql_data_at(:project, :ciUpstreamProjectSubscriptions, :nodes)).to be_empty
      end
    end
  end
end
