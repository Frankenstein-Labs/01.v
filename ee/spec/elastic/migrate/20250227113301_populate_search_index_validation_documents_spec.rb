# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250227113301_populate_search_index_validation_documents.rb')

RSpec.describe PopulateSearchIndexValidationDocuments, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250227113301
end
