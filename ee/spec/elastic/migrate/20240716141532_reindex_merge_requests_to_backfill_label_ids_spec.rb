# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240716141532_reindex_merge_requests_to_backfill_label_ids.rb')

RSpec.describe ReindexMergeRequestsToBackfillLabelIds, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240716141532
end
