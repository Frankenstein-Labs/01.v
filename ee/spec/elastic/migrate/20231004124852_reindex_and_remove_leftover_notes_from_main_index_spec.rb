# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20231004124852_reindex_and_remove_leftover_notes_from_main_index.rb')

RSpec.describe ReindexAndRemoveLeftoverNotesFromMainIndex, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20231004124852
end
