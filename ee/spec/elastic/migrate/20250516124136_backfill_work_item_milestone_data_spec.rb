# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250516124136_backfill_work_item_milestone_data.rb')

RSpec.describe BackfillWorkItemMilestoneData, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250516124136
end
