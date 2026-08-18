# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::AggregationCache, :clean_gitlab_redis_cache, feature_category: :global_search do
  let_it_be(:user) { create(:user) }

  let(:query) { 'foo' }
  let(:group_id) { nil }
  let(:project_id) { nil }
  let(:filters) do
    { include_archived: false, exclude_forks: false }
  end

  let(:tally) do
    { 'Ruby' => 10, 'JavaScript' => 5 }
  end

  subject(:cache) do
    described_class.new(
      query,
      current_user: user,
      filters: filters,
      group_id: group_id,
      project_id: project_id
    )
  end

  describe '#read' do
    context 'when the cache is empty' do
      it 'returns nil' do
        expect(cache.read).to be_nil
      end
    end

    context 'when the cache has been populated' do
      before do
        cache.write(tally)
      end

      it 'returns the cached tally' do
        expect(cache.read).to eq(tally)
      end
    end
  end

  describe '#write' do
    it 'stores the tally so it can be read back' do
      cache.write(tally)

      expect(cache.read).to eq(tally)
    end

    it 'no-ops when the tally is nil' do
      cache.write(nil)

      expect(cache.read).to be_nil
    end

    it 'no-ops when the tally is empty' do
      cache.write({})

      expect(cache.read).to be_nil
    end

    it 'does not overwrite an existing entry' do
      cache.write(tally)
      cache.write({ 'Ruby' => 999 })

      expect(cache.read).to eq(tally)
    end
  end

  describe 'cache key isolation' do
    let(:other_query_cache) do
      described_class.new(
        'bar',
        current_user: user,
        filters: filters,
        group_id: group_id,
        project_id: project_id
      )
    end

    let_it_be(:other_user) { create(:user) }
    let(:other_user_cache) do
      described_class.new(
        query,
        current_user: other_user,
        filters: filters,
        group_id: group_id,
        project_id: project_id
      )
    end

    before do
      cache.write(tally)
    end

    it 'does not share cache entries across different queries' do
      expect(other_query_cache.read).to be_nil
    end

    it 'does not share cache entries across different users' do
      expect(other_user_cache.read).to be_nil
    end
  end

  describe 'filter normalization' do
    context 'when the language filter is set' do
      let(:filters_with_language) do
        { include_archived: false, exclude_forks: false, language: ['Ruby'] }
      end

      let(:cache_with_language) do
        described_class.new(
          query,
          current_user: user,
          filters: filters_with_language,
          group_id: group_id,
          project_id: project_id
        )
      end

      before do
        cache.write(tally)
      end

      it 'ignores the language filter for fingerprinting' do
        expect(cache_with_language.read).to eq(tally)
      end
    end

    context 'when boolean filters arrive as nil (REST endpoint)' do
      let(:filters_with_nils) do
        { include_archived: nil, exclude_forks: nil }
      end

      let(:cache_with_nils) do
        described_class.new(
          query,
          current_user: user,
          filters: filters_with_nils,
          group_id: group_id,
          project_id: project_id
        )
      end

      before do
        cache.write(tally)
      end

      it 'treats nil boolean filters as false so they hit the same cache entry' do
        expect(cache_with_nils.read).to eq(tally)
      end
    end

    context 'when include_archived differs' do
      let(:filters_archived) do
        { include_archived: true, exclude_forks: false }
      end

      let(:cache_archived) do
        described_class.new(
          query,
          current_user: user,
          filters: filters_archived,
          group_id: group_id,
          project_id: project_id
        )
      end

      before do
        cache.write(tally)
      end

      it 'produces a different cache entry' do
        expect(cache_archived.read).to be_nil
      end
    end

    context 'when exclude_forks differs' do
      let(:filters_forks) do
        { include_archived: false, exclude_forks: true }
      end

      let(:cache_forks) do
        described_class.new(
          query,
          current_user: user,
          filters: filters_forks,
          group_id: group_id,
          project_id: project_id
        )
      end

      before do
        cache.write(tally)
      end

      it 'produces a different cache entry' do
        expect(cache_forks.read).to be_nil
      end
    end

    context 'when filters use string keys' do
      let(:string_filters) do
        { 'include_archived' => false, 'exclude_forks' => false }
      end

      let(:string_key_cache) do
        described_class.new(
          query,
          current_user: user,
          filters: string_filters,
          group_id: group_id,
          project_id: project_id
        )
      end

      before do
        cache.write(tally)
      end

      it 'treats string and symbol keys identically' do
        expect(string_key_cache.read).to eq(tally)
      end
    end
  end

  describe 'search_mode isolation' do
    let(:regex_cache) do
      described_class.new(
        query,
        current_user: user,
        filters: filters,
        group_id: group_id,
        project_id: project_id,
        search_mode: :regex
      )
    end

    let(:exact_cache) do
      described_class.new(
        query,
        current_user: user,
        filters: filters,
        group_id: group_id,
        project_id: project_id,
        search_mode: :exact
      )
    end

    it 'produces distinct cache entries for regex and exact modes' do
      regex_cache.write(tally)

      expect(exact_cache.read).to be_nil
      expect(regex_cache.read).to eq(tally)
    end

    it 'treats symbol and string mode identically' do
      regex_cache.write(tally)

      string_mode_cache = described_class.new(
        query,
        current_user: user,
        filters: filters,
        group_id: group_id,
        project_id: project_id,
        search_mode: 'regex'
      )

      expect(string_mode_cache.read).to eq(tally)
    end

    it 'defaults to :exact when no mode is passed' do
      exact_cache.write(tally)

      default_cache = described_class.new(
        query,
        current_user: user,
        filters: filters,
        group_id: group_id,
        project_id: project_id
      )

      expect(default_cache.read).to eq(tally)
    end
  end

  describe 'scope isolation' do
    let(:group_cache) do
      described_class.new(
        query,
        current_user: user,
        filters: filters,
        group_id: 42,
        project_id: nil
      )
    end

    let(:project_cache) do
      described_class.new(
        query,
        current_user: user,
        filters: filters,
        group_id: nil,
        project_id: 42
      )
    end

    before do
      cache.write(tally)
    end

    it 'uses a distinct key for group-scoped searches' do
      expect(group_cache.read).to be_nil
    end

    it 'uses a distinct key for project-scoped searches' do
      expect(project_cache.read).to be_nil
    end
  end

  describe 'anonymous users' do
    subject(:anonymous_cache) do
      described_class.new(
        query,
        current_user: nil,
        filters: filters,
        group_id: group_id,
        project_id: project_id
      )
    end

    it 'writes and reads without a current_user' do
      anonymous_cache.write(tally)

      expect(anonymous_cache.read).to eq(tally)
    end
  end
end
