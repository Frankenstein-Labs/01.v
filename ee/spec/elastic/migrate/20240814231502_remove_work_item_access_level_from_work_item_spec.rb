# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240814231502_remove_work_item_access_level_from_work_item.rb')

RSpec.describe RemoveWorkItemAccessLevelFromWorkItem, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240814231502
end
