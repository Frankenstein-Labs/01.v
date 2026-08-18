# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250529160735_add_traversal_ids_to_notes.rb')

RSpec.describe AddTraversalIdsToNotes, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250529160735
end
