# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250220225059_reindex_notes_to_update_integer_with_long_type.rb')

RSpec.describe ReindexNotesToUpdateIntegerWithLongType, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250220225059
end
