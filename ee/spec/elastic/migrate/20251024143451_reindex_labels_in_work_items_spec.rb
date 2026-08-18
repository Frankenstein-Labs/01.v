# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20251024143451_reindex_labels_in_work_items.rb')

RSpec.describe ReindexLabelsInWorkItems, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20251024143451
end
