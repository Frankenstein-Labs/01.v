# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240130215043_reindex_wikis_to_fix_id.rb')

RSpec.describe ReindexWikisToFixId, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240130215043
end
