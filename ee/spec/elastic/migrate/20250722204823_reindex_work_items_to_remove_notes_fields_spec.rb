# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250722204823_reindex_work_items_to_remove_notes_fields.rb')

RSpec.describe ReindexWorkItemsToRemoveNotesFields, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250722204823
end
