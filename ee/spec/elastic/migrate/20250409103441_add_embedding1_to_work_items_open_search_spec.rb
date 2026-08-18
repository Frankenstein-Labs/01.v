# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250409103441_add_embedding1_to_work_items_open_search.rb')

RSpec.describe AddEmbedding1ToWorkItemsOpenSearch, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250409103441
end
