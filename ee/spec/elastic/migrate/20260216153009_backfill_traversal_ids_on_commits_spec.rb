# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20260216153009_backfill_traversal_ids_on_commits.rb')

RSpec.describe BackfillTraversalIdsOnCommits, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20260216153009
end
