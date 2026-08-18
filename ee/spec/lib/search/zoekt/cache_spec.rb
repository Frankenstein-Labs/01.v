# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Cache, :clean_gitlab_redis_cache, feature_category: :global_search do
  let(:search_mode) { 'regex' }
  let(:per_page) { 20 }
  let(:query) { 'foo' }
  let_it_be(:user1) { build(:user, id: 1) }
  let(:page) { 1 }
  let(:project_id) { 1 }
  let(:group_id) { 2 }
  let(:total_count) { 3 }
  let(:file_count) { 3 }
  let(:count_only) { true }
  let(:response) { [search_results, total_count, file_count] }
  let(:search_results) do
    { 0 => { project_id: 1 }, 1 => { project_id: 2 }, 2 => { project_id: 3 } }
  end

  let(:filters) do
    {}
  end

  let(:default_options) do
    {
      per_page: per_page,
      chunk_size: 3,
      max_per_page: 40,
      search_mode: search_mode,
      filters: filters,
      count_only: count_only
    }
  end

  subject(:cache) do
    described_class.new(
      query,
      **default_options.merge(current_user: user1, project_id: project_id, group_id: group_id, page: page)
    )
  end

  before do
    stub_const("#{described_class.name}::MAX_PAGES", 2)
  end

  describe '#fetch' do
    context 'when application setting zoekt_cache_response is disabled', :zoekt_cache_disabled do
      it 'does not read or update cache' do
        expect(cache).not_to receive(:read_cache)
        expect(cache).not_to receive(:update_cache!)

        data = cache.fetch do |page_limit|
          expect(page_limit).to eq(page)
          response
        end

        expect(data).to eq(response)
      end
    end

    context 'when read_cache returns nothing' do
      it 'updates cache' do
        expect(cache).to receive(:read_cache)
        expect(cache).to receive(:update_cache!)

        data = cache.fetch do |page_limit|
          expect(page_limit).to eq(described_class::MAX_PAGES)
          response
        end

        expect(data).to eq(response)
      end
    end

    context 'when read_cache returns data' do
      it 'does not update cache' do
        expect(cache).to receive(:read_cache).and_return([search_results, total_count, file_count])
        expect(cache).not_to receive(:update_cache!)

        data = cache.fetch do |page_limit|
          expect(page_limit).to eq(described_class::MAX_PAGES)
          response
        end

        expect(data).to eq(response)
      end
    end

    context 'when page is higher than the limit' do
      let(:page) { 3 }

      it 'sets the correct page limit' do
        data = cache.fetch do |page_limit|
          expect(page_limit).to eq(page)
          response
        end

        expect(data).to eq(response)
      end
    end

    context 'when page is beyond MAX_PAGES' do
      let(:page) { described_class::MAX_PAGES + 1 }

      context 'when offset pagination is NOT active' do
        before do
          allow(Search::Zoekt::OffsetPagination).to receive(:active?).and_return(false)
        end

        it 'still reads and writes cache as before' do
          expect(cache).to receive(:read_cache).and_return(nil)
          expect(cache).to receive(:update_cache!)

          cache.fetch { response }
        end
      end

      context 'when offset pagination is active' do
        before do
          allow(Search::Zoekt::OffsetPagination).to receive(:active?).and_return(true)
        end

        it 'bypasses the cache entirely — does not read or write' do
          expect(cache).not_to receive(:read_cache)
          expect(cache).not_to receive(:update_cache!)

          cache.fetch { response }
        end

        it 'does not overwrite the cached pages 1-MAX_PAGES' do
          redis = ::Gitlab::Redis::Cache.with { |r| r }
          data = "#{query}-g#{group_id}-p#{project_id}-#{search_mode}-3-#{Gitlab::Json.generate(filters.sort)}"
          fingerprint = OpenSSL::Digest.hexdigest('SHA256', data)
          page1_key = "cache:zoekt:{#{user1.id}}/#{count_only}/#{fingerprint}/#{per_page}/1"

          # Seed page 1 in cache
          sentinel = Marshal.dump([{ 0 => { project_id: 99 } }, 1, 1])
          redis.set(page1_key, sentinel, ex: 60)

          # Request page 11 with offset pagination active - should not touch the cache
          cache.fetch { response }

          expect(redis.get(page1_key)).to eq(sentinel)
        end
      end
    end

    describe 'cache key' do
      let(:redis) { ::Gitlab::Redis::Cache.with { |r| r } }
      let(:data) { "#{query}-g#{group_id}-p#{project_id}-#{search_mode}-3-#{Gitlab::Json.generate(filters.sort)}" }
      let(:fingerprint) { OpenSSL::Digest.hexdigest('SHA256', data) }

      context 'when current_user is nil' do
        let(:user1) { nil }

        it 'sets 0 for user_id key' do
          cache.fetch { response }
          expect(redis.exists?("cache:zoekt:{0}/true/#{fingerprint}/#{per_page}/#{page}")).to be true
        end
      end

      context 'when current_user exists' do
        it 'sets user_id in the key' do
          cache.fetch { response }
          expect(redis.exists?("cache:zoekt:{#{user1.id}}/true/#{fingerprint}/#{per_page}/#{page}")).to be true
        end
      end

      context 'when count_only is false' do
        let(:count_only) { false }

        it 'sets false in the key' do
          cache.fetch { response }
          expect(redis.exists?("cache:zoekt:{#{user1.id}}/false/#{fingerprint}/#{per_page}/#{page}")).to be true
        end
      end
    end

    describe 'count-only caching' do
      let(:count_only) { true }
      let(:file_count) { 0 }
      let(:search_results) { {} }
      let(:response) { [search_results, total_count, file_count] }

      context 'when count_only is true and file_count is 0' do
        it 'caches the count result' do
          data = cache.fetch { response }

          expect(data).to eq(response)

          # Verify data was cached by checking Redis
          redis = ::Gitlab::Redis::Cache.with { |r| r }
          data = "#{query}-g#{group_id}-p#{project_id}-#{search_mode}-3-#{Gitlab::Json.generate(filters.sort)}"
          fingerprint = OpenSSL::Digest.hexdigest('SHA256', data)
          cached_data = redis.get("cache:zoekt:{#{user1.id}}/#{count_only}/#{fingerprint}/#{per_page}/#{page}")

          expect(cached_data).not_to be_nil
          # For count-only queries, search_results is {}, so search_results[0] is nil
          expect(Marshal.load(cached_data)).to match_array([{ 0 => nil }, total_count, file_count]) # rubocop:disable Security/MarshalLoad -- Testing cache serialization
        end

        it 'returns cached count on subsequent calls' do
          # First call - populates cache
          first_call_result = cache.fetch { response }
          expect(first_call_result).to eq(response)

          # Second call - should use cache without yielding
          # The cached result has a slightly different structure: {0 => nil} instead of {}
          expect do |block|
            second_call_result = cache.fetch(&block)
            # When retrieved from cache, search_results becomes {0 => nil}
            expect(second_call_result).to match_array([{ 0 => nil }, total_count, file_count])
          end.not_to yield_control
        end
      end

      context 'when count_only is false and file_count is 0' do
        let(:count_only) { false }

        it 'does not cache the result' do
          data = cache.fetch { response }

          expect(data).to eq(response)

          # Verify data was not cached
          redis = ::Gitlab::Redis::Cache.with { |r| r }
          data = "#{query}-g#{group_id}-p#{project_id}-#{search_mode}-3-#{Gitlab::Json.generate(filters.sort)}"
          fingerprint = OpenSSL::Digest.hexdigest('SHA256', data)
          cached_data = redis.get("cache:zoekt:{#{user1.id}}/#{count_only}/#{fingerprint}/#{per_page}/#{page}")

          expect(cached_data).to be_nil
        end
      end
    end
  end
end
