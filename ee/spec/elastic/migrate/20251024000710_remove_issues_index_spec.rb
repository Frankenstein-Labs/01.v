# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20251024000710_remove_issues_index.rb')

RSpec.describe RemoveIssuesIndex, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20251024000710
end
