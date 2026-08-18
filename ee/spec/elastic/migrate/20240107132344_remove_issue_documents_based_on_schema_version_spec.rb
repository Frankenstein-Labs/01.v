# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240107132344_remove_issue_documents_based_on_schema_version.rb')

RSpec.describe RemoveIssueDocumentsBasedOnSchemaVersion, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240107132344
end
