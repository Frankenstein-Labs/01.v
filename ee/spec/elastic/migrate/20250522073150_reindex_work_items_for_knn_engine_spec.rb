# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250522073150_reindex_work_items_for_knn_engine.rb')

RSpec.describe ReindexWorkItemsForKnnEngine, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250522073150
end
