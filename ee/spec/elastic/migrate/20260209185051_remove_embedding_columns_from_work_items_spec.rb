# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20260209185051_remove_embedding_columns_from_work_items.rb')

RSpec.describe RemoveEmbeddingColumnsFromWorkItems, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20260209185051
end
