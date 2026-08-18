# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20231019223356_reindex_wikis_to_fix_routing_and_backfill_archived.rb')

RSpec.describe ReindexWikisToFixRoutingAndBackfillArchived, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20231019223356
end
