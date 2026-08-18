# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240816132114_backfill_work_items.rb')

RSpec.describe BackfillWorkItems, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240816132114
end
