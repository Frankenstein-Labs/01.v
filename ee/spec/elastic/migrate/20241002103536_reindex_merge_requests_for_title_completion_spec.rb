# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20241002103536_reindex_merge_requests_for_title_completion.rb')

RSpec.describe ReindexMergeRequestsForTitleCompletion, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20241002103536
end
