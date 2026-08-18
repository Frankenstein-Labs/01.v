# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240119130539_reindex_notes_to_update_analyzer.rb')

RSpec.describe ReindexNotesToUpdateAnalyzer, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240119130539
end
