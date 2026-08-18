# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240104134928_reindex_all_issues.rb')

RSpec.describe ReindexAllIssues, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240104134928
end
