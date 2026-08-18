# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20231213172132_reindex_all_epics.rb')

RSpec.describe ReindexAllEpics, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20231213172132
end
