# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Destroy a Maven cache entry', :sidekiq_inline, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
  let_it_be_with_reload(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }
  let_it_be_with_reload(:cache_entry) do
    create(:virtual_registries_packages_maven_cache_remote_entry, upstream: upstream, group: group)
  end

  let(:mutation_params) do
    {
      id: cache_entry.generate_id
    }
  end

  let(:faulty_mutation_params) do
    {
      id: nil
    }
  end

  let(:invalid_record_params) do
    {
      id: Base64.urlsafe_encode64("#{non_existing_record_id} #{non_existing_record_id}")
    }
  end

  def maven_cache_entry_delete_mutation(params = mutation_params)
    graphql_mutation(:mavenCacheEntryDelete, params)
  end

  before_all do
    group.add_maintainer(current_user)
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
  end

  shared_examples 'returning error message' do
    let(:error_msg) do
      "The resource that you are attempting to access does " \
        "not exist or you don't have permission to perform this action"
    end

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to include(a_hash_including('message' => error_msg))
    end
  end

  it 'marks the cache entry as pending_destruction' do
    expect do
      post_graphql_mutation(maven_cache_entry_delete_mutation, current_user: current_user)
    end.to change { cache_entry.reload.status }.from('default').to('pending_destruction')
  end

  it 'returns the cache entry' do
    post_graphql_mutation(maven_cache_entry_delete_mutation, current_user: current_user)

    expect(graphql_data_at(:mavenCacheEntryDelete, :cacheEntry, :id)).to be_present
  end

  context 'when mutation params are invalid' do
    it_behaves_like 'returning error message' do
      let(:mutation) { maven_cache_entry_delete_mutation(faulty_mutation_params) }
      let(:error_msg) do
        "Variable $mavenCacheEntryDeleteInput of type MavenCacheEntryDeleteInput! " \
          "was provided invalid value for id (Expected value to not be null)"
      end
    end
  end

  it_behaves_like 'returning error message' do
    let(:mutation) { maven_cache_entry_delete_mutation(invalid_record_params) }
  end

  context 'when packages_virtual_registry licensed feature is unavailable' do
    before do
      stub_licensed_features(packages_virtual_registry: false)
    end

    it_behaves_like 'returning error message' do
      let(:mutation) { maven_cache_entry_delete_mutation }
    end
  end

  context 'with maven_virtual_registry feature flag turned off' do
    before do
      stub_feature_flags(maven_virtual_registry: false)
    end

    it_behaves_like 'returning error message' do
      let(:mutation) { maven_cache_entry_delete_mutation }
    end
  end
end
