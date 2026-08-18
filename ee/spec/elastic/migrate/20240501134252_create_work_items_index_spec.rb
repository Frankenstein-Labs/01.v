# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240501134252_create_work_items_index.rb')

RSpec.describe CreateWorkItemsIndex, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240501134252
end
