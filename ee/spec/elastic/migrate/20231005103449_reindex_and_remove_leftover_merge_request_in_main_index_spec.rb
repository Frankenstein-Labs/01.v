# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20231005103449_reindex_and_remove_leftover_merge_request_in_main_index.rb')

RSpec.describe ReindexAndRemoveLeftoverMergeRequestInMainIndex, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20231005103449
end
