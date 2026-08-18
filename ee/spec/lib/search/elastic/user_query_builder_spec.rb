# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::UserQueryBuilder, :elastic_helpers, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let(:base_options) do
    {
      current_user: user,
      search_level: 'global'
    }
  end

  let(:query) { 'bob' }
  let(:options) { base_options }

  subject(:build) { described_class.build(query: query, options: options) }

  describe 'query' do
    context 'when query is plain text' do
      it 'uses fuzzy match queries' do
        assert_names_in_query(build,
          with: %w[user:fuzzy:name user:fuzzy:username user:fuzzy:public_email],
          without: %w[
            user:fuzzy:email
            user:match:search_terms
            user:multi_match:and:search_terms
            user:multi_match_phrase:search_terms
          ])
      end
    end

    context 'when query contains advanced query syntax characters' do
      let(:query) { 'bo*' }

      it 'uses a simple query string match' do
        assert_names_in_query(build,
          with: %w[user:match:search_terms],
          without: %w[user:fuzzy:name user:multi_match:and:search_terms user:multi_match_phrase:search_terms])
      end
    end

    context 'when query uses advanced syntax with operators' do
      let(:query) { 'bob -smith' }

      it 'uses a simple query string match' do
        assert_names_in_query(build,
          with: %w[user:match:search_terms],
          without: %w[user:multi_match:and:search_terms user:fuzzy:name])
      end
    end
  end

  describe 'filters' do
    describe 'forbidden state' do
      it 'filters out users in forbidden state by default' do
        assert_names_in_query(build, with: %w[filters:not_forbidden_state])
      end

      context 'when user can read all resources' do
        before do
          allow(user).to receive(:can_admin_all_resources?).and_return(true)
        end

        it 'does not apply the forbidden state filter' do
          assert_names_in_query(build, without: %w[filters:not_forbidden_state])
        end
      end
    end

    describe 'fields' do
      it 'excludes private email for non-admins' do
        assert_names_in_query(build, without: %w[user:fuzzy:email])
      end

      context 'when user can read all resources' do
        before do
          allow(user).to receive(:can_admin_all_resources?).and_return(true)
        end

        it 'includes private email' do
          assert_names_in_query(build, with: %w[user:fuzzy:email])
        end
      end

      context 'when current_user is nil (anonymous)' do
        let(:options) { base_options.merge(current_user: nil) }

        it 'excludes private email' do
          assert_names_in_query(build, without: %w[user:fuzzy:email])
        end
      end
    end

    describe 'count_only' do
      context 'when count_only is true' do
        let(:options) { base_options.merge(count_only: true) }

        it 'sets size to 0, retains fuzzy queries, and applies forbidden state filter' do
          result = build

          expect(result).to include(size: 0)
          assert_names_in_query(result,
            with: %w[user:fuzzy:name user:fuzzy:username user:fuzzy:public_email filters:not_forbidden_state])
        end
      end
    end
  end

  it_behaves_like 'a sorted query'

  describe 'formats' do
    it_behaves_like 'a query that sets source_fields'
    it_behaves_like 'a query formatted for size'
  end
end
