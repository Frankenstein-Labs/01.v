# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250717120142_index_work_items_milestone_state.rb')

RSpec.describe IndexWorkItemsMilestoneState, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250717120142
end
