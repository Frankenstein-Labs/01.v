# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250718114546_backfill_milestone_state_work_items_index.rb')

RSpec.describe BackfillMilestoneStateWorkItemsIndex, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250718114546
end
