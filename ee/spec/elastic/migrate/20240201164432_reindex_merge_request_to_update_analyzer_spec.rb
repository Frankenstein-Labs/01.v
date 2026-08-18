# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240201164432_reindex_merge_request_to_update_analyzer.rb')

RSpec.describe ReindexMergeRequestToUpdateAnalyzer, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240201164432
end
