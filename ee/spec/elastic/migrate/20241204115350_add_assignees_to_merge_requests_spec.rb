# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20241204115350_add_assignees_to_merge_requests.rb')

RSpec.describe AddAssigneesToMergeRequests, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20241204115350
end
