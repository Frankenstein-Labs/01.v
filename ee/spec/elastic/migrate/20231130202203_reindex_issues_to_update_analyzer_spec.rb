# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20231130202203_reindex_issues_to_update_analyzer.rb')

RSpec.describe ReindexIssuesToUpdateAnalyzer, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20231130202203
end
