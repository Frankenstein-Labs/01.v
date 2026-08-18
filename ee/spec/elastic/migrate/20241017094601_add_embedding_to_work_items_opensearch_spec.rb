# frozen_string_literal: true

require 'spec_helper'
# require_relative 'migration_shared_examples'
require File.expand_path('ee/elastic/migrate/20241017094601_add_embedding_to_work_items_opensearch.rb')

RSpec.describe AddEmbeddingToWorkItemsOpensearch, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20241017094601
end
