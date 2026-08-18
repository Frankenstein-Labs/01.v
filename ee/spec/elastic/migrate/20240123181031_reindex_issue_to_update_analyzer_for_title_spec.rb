# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240123181031_reindex_issue_to_update_analyzer_for_title.rb')

RSpec.describe ReindexIssueToUpdateAnalyzerForTitle, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240123181031
end
