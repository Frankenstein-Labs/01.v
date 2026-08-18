# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250218133000_reindex_work_items_for_type_id_alignment.rb')

RSpec.describe ReindexWorkItemsForTypeIdAlignment, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250218133000
end
