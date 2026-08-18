# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::VirtualRegistries::Cache::EntriesFinder, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group, :private) }

  shared_examples 'cache entries finder' do |cache_entry_factory:, upstream_factory:|
    let_it_be_with_reload(:upstream) { create(upstream_factory, group: group) }
    # `freeze: false` is required here: this `let_it_be` subject is mutated
    # in-memory across examples in a way that survives both
    # `let_it_be_with_reload` and `let_it_be_with_refind` (e.g. a memoized
    # association/collection or a non-persisted attribute). Keeping it unfrozen
    # is the only correct cure (see gitlab-org/gitlab#602925).
    let_it_be(:cache_entries, freeze: false) { create_list(cache_entry_factory, 2, upstream: upstream) }

    describe '#execute' do
      let(:params) { {} }

      subject(:find_cache_entries) do
        described_class.new(upstream: upstream, params: params).execute
      end

      it { is_expected.to match_array(cache_entries).and be_a(ActiveRecord::Relation) }

      context 'with search' do
        let(:params) { { search: 'foo' } }

        let_it_be(:cache_entry1) do
          create(cache_entry_factory, upstream: upstream, relative_path: '/path/foo/file.txt')
        end

        let_it_be(:cache_entry2) do
          create(cache_entry_factory, upstream: upstream, relative_path: '/path/bar/file.txt')
        end

        it 'returns cache entries which match the given search term' do
          expect(find_cache_entries).to match_array([cache_entry1])
        end
      end

      context 'when cache entry is marked for destruction' do
        before do
          cache_entries.first.pending_destruction!
        end

        it { is_expected.to match_array([cache_entries.last]) }
      end
    end
  end

  describe 'Maven cache entries' do
    it_behaves_like 'cache entries finder',
      cache_entry_factory: :virtual_registries_packages_maven_cache_remote_entry,
      upstream_factory: :virtual_registries_packages_maven_upstream
  end

  describe 'Container cache entries' do
    it_behaves_like 'cache entries finder',
      cache_entry_factory: :virtual_registries_container_cache_remote_entry,
      upstream_factory: :virtual_registries_container_upstream
  end
end
