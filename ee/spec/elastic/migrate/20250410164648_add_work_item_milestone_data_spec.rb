# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250410164648_add_work_item_milestone_data.rb')

RSpec.describe AddWorkItemMilestoneData, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250410164648
end
