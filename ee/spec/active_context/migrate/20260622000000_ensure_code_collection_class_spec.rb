# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/active_context/migrate/20260622000000_ensure_code_collection_class.rb')

RSpec.describe EnsureCodeCollectionClass, feature_category: :global_search do
  let(:version) { 20260622000000 }
  let(:migration_class) { ::ActiveContext::Migration::Dictionary.instance.find_by_version(version) }
  let(:collection) { create(:ai_active_context_collection, :code_collection) }

  subject(:migrate) { migration_class.new.migrate! }

  context 'when collection_class is nil' do
    before do
      collection.update_metadata!(collection_class: nil)
    end

    it 'sets collection_class on the collection' do
      expect { migrate }.to change {
        collection.reload.collection_class
      }.from(nil).to('Ai::ActiveContext::Collections::Code')
    end
  end

  context 'when collection_class is already set' do
    before do
      collection.update_metadata!(collection_class: 'Ai::ActiveContext::Collections::Code')
    end

    it 'does not change the collection_class' do
      expect { migrate }.not_to change {
        collection.reload.collection_class
      }
    end
  end
end
