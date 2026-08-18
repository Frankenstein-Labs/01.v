# frozen_string_literal: true

require 'spec_helper'
require File.expand_path(
  'ee/elastic/migrate/20251015110640_reindex_work_items_to_update_integer_with_long_type_third_attempt.rb'
)

RSpec.describe ReindexWorkItemsToUpdateIntegerWithLongTypeThirdAttempt, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20251015110640
end
