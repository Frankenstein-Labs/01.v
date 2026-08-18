# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20251024000709_remove_epics_index.rb')

RSpec.describe RemoveEpicsIndex, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20251024000709
end
