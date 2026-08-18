# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20260806094231_create_groups_index.rb')

RSpec.describe CreateGroupsIndex, feature_category: :global_search do
  it_behaves_like 'migration creates a new index', 20260806094231, ::Group
end
