# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20241107144941_backfill_traversal_ids_on_merge_requests.rb')

RSpec.describe BackfillTraversalIdsOnMergeRequests, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20241107144941
end
