# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240410193847_add_embedding_to_issues.rb')

RSpec.describe AddEmbeddingToIssues, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240410193847
end
