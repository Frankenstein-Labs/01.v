# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250605120024_backfill_new_fields_in_work_items.rb')

RSpec.describe BackfillNewFieldsInWorkItems, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250605120024
end
