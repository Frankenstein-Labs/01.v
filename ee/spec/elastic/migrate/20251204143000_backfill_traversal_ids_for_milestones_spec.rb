# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20251204143000_backfill_traversal_ids_for_milestones.rb')

RSpec.describe BackfillTraversalIdsForMilestones, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20251204143000
end
