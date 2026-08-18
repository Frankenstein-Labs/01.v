# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/active_context/migrate/20260213124605_update_code_model_metadata.rb')

RSpec.describe UpdateCodeModelMetadata, feature_category: :code_suggestions do
  let(:version) { 20260213124605 }
  let(:migration_class) { ::ActiveContext::Migration::Dictionary.instance.find_by_version(version) }
  let_it_be(:collection) { create(:ai_active_context_collection, :code_collection) }

  let(:expected_model_metadata) { { model_ref: 'text_embedding_005_vertex', field: 'embeddings_v1' } }

  subject(:migrate) { migration_class.new.migrate! }

  it 'sets current_indexing_embedding_model on the collection' do
    expect { migrate }.to change {
      collection.reload.current_indexing_embedding_model
    }.from(nil).to(expected_model_metadata)
  end

  it 'sets search_embedding_model on the collection' do
    expect { migrate }.to change {
      collection.reload.search_embedding_model
    }.from(nil).to(expected_model_metadata)
  end

  describe '#skip?' do
    it 'checks the presence of the self-hosted AIGW url' do
      migration = migration_class.new

      allow(::Gitlab::AiGateway).to receive(:has_self_hosted_ai_gateway?).and_return(false)
      expect(migration.skip?).to be(false)

      allow(::Gitlab::AiGateway).to receive(:has_self_hosted_ai_gateway?).and_return(true)
      expect(migration.skip?).to be(true)
    end
  end
end
