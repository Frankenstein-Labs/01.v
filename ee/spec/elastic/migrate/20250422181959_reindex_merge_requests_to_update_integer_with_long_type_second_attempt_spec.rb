# frozen_string_literal: true

require 'spec_helper'
require File.expand_path(
  'ee/elastic/migrate/20250422181959_reindex_merge_requests_to_update_integer_with_long_type_second_attempt.rb'
)

RSpec.describe ReindexMergeRequestsToUpdateIntegerWithLongTypeSecondAttempt, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250422181959
end
