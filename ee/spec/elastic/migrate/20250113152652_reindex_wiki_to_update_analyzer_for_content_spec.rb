# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250113152652_reindex_wiki_to_update_analyzer_for_content.rb')

RSpec.describe ReindexWikiToUpdateAnalyzerForContent, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250113152652
end
