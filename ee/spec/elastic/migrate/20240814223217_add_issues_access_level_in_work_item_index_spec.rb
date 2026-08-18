# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240814223217_add_issues_access_level_in_work_item_index.rb')

RSpec.describe AddIssuesAccessLevelInWorkItemIndex, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240814223217
end
