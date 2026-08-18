# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/active_context/migrate/20260330103204_remove_deprecated_version_metadata.rb')

RSpec.describe RemoveDeprecatedVersionMetadata, feature_category: :global_search do
  let(:version) { 20260330103204 }
  let(:migration_class) { ::ActiveContext::Migration::Dictionary.instance.find_by_version(version) }
  let_it_be_with_reload(:collection) { create(:ai_active_context_collection, :code_collection) }

  subject(:migrate) { migration_class.new.migrate! }

  before do
    collection.update_column(
      :metadata,
      {
        'indexing_embedding_versions' => [1, 2],
        'search_embedding_version' => 3,
        'current_indexing_embedding_model' => { 'model_ref' => 'test', 'field' => 'embeddings' }
      }
    )
  end

  it 'removes indexing_embedding_versions and search_embedding_version from metadata' do
    migrate

    expect(collection.reload.metadata.keys).to match_array(%w[current_indexing_embedding_model])
  end

  it 'preserves other metadata fields' do
    migrate

    expect(collection.reload.metadata['current_indexing_embedding_model']).to eq(
      { 'model_ref' => 'test', 'field' => 'embeddings' }
    )
  end
end
