# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20241106201829_reindex_work_items_based_on_schema.rb')

RSpec.describe ReindexWorkItemsBasedOnSchema, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20241106201829
end
