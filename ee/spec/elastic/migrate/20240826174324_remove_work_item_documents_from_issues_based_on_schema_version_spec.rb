# frozen_string_literal: true

require 'spec_helper'
require File.expand_path(
  'ee/elastic/migrate/20240826174324_remove_work_item_documents_from_issues_based_on_schema_version.rb'
)

RSpec.describe RemoveWorkItemDocumentsFromIssuesBasedOnSchemaVersion, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240826174324
end
