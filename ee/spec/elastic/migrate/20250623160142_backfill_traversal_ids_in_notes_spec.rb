# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250623160142_backfill_traversal_ids_in_notes.rb')

RSpec.describe BackfillTraversalIdsInNotes, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250623160142
end
