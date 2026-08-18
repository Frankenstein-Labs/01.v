# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240826172514_remove_issue_documents_before_schema_version2408.rb')

RSpec.describe RemoveIssueDocumentsBeforeSchemaVersion2408, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240826172514
end
