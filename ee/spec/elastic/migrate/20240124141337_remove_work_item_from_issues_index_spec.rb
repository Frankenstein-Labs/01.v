# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240124141337_remove_work_item_from_issues_index.rb')

RSpec.describe RemoveWorkItemFromIssuesIndex, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240124141337
end
